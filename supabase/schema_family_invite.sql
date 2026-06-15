-- schema_family_invite.sql
-- BabyLog · 가족 피드 초대 합류 RPC — 안드로이드/웹 조부모가 초대 링크로 가족에 합류.
-- 배경: bl_family_member 의 RLS는 INSERT를 '소유자만' 허용하고 UPDATE 정책이 없어,
--       조부모(아직 멤버 아님)는 스스로 멤버 행을 만들/고칠 수 없다(닭-달걀).
--       → security definer 함수로 '초대 코드'를 검증한 뒤 본인(auth.uid) 멤버 행을 만든다.
-- 멱등: create or replace. 재실행 안전.
-- 전제: schema_family_feed.sql 이 먼저 적용되어 bl_family_member / bl_owner_id() 존재.

-- 초대 코드 조회 인덱스(코드로 가족 찾기 — unique라 이미 인덱스가 있으나 명시)
create index if not exists idx_bl_member_invite on public.bl_family_member(invite_code);

-- 초대 코드로 가족 합류. 반환: 합류한 family_id (실패 시 예외).
--  · 부모(소유자)가 만든 미사용 초대 행(uid is null, invite_code=코드)을 본인이 'claim'.
--  · 같은 링크를 여러 조부모가 써도 되도록: 이미 claim된 코드면 같은 가족에 새 멤버 행 추가.
--  · 이미 그 가족 멤버면 멱등으로 family_id만 반환.
create or replace function public.bl_claim_invite(p_code text, p_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me  text;
  fam uuid;
begin
  me := public.bl_owner_id();
  if me is null then
    raise exception 'auth required';
  end if;
  if coalesce(p_code, '') = '' then
    raise exception 'invalid invite';
  end if;

  -- 코드가 가리키는 가족
  select family_id into fam
    from public.bl_family_member
   where invite_code = p_code
   limit 1;
  if fam is null then
    raise exception 'invalid invite';
  end if;

  -- 이미 이 가족 멤버면 그대로 반환(멱등)
  if exists (
    select 1 from public.bl_family_member
     where family_id = fam and uid = me
  ) then
    return fam;
  end if;

  -- 미사용 초대 행(첫 합류자)을 claim
  update public.bl_family_member
     set uid = me,
         joined_at = now(),
         display_name = coalesce(nullif(p_name, ''), display_name)
   where invite_code = p_code and uid is null;

  -- 이미 claim된 코드(둘째 이후 합류자) → 같은 가족에 새 멤버 행 추가
  if not found then
    insert into public.bl_family_member (family_id, uid, role, display_name, joined_at)
    values (fam, me, 'grandparent', coalesce(nullif(p_name, ''), '가족'), now());
  end if;

  return fam;
end;
$$;

grant execute on function public.bl_claim_invite(text, text) to anon, authenticated;

-- 내 표시 이름 설정/교정 — 웹 조부모가 입력한 성함을 멤버 행에 반영(댓글 작성자명).
-- RLS에 bl_family_member UPDATE 정책이 없어 직접 못 고치므로 security definer로 본인 행만 갱신.
create or replace function public.bl_set_my_name(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(p_name, '') = '' then return; end if;
  update public.bl_family_member
     set display_name = left(p_name, 40)
   where uid = public.bl_owner_id();
end;
$$;

grant execute on function public.bl_set_my_name(text) to anon, authenticated;

-- ════════════════ 초대 비밀번호(보안) ════════════════
-- 링크만으로는 합류 불가 — 부모가 정한 '가족 비밀번호'까지 맞아야 합류(2차 확인).
-- 비밀번호는 해시로만 저장(평문 미보관). 이미 합류한 멤버는 재방문 시 비번 불필요.

create extension if not exists pgcrypto with schema extensions;

alter table public.bl_family add column if not exists join_pass_hash text;

-- 가족 비밀번호 설정/변경 — 소유자(부모)만.
create or replace function public.bl_set_family_pass(p_family uuid, p_pass text)
returns void
language plpgsql security definer set search_path = public, extensions
as $$
begin
  if coalesce(p_pass, '') = '' then return; end if;
  update public.bl_family
     set join_pass_hash = crypt(p_pass, gen_salt('bf'))
   where id = p_family and owner_uid = public.bl_owner_id();
end;
$$;
grant execute on function public.bl_set_family_pass(uuid, text) to anon, authenticated;

-- 비밀번호 검증을 포함한 합류(3-arg 오버로드). 웹은 이걸 호출한다.
create or replace function public.bl_claim_invite(p_code text, p_name text, p_pass text)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare me text; fam uuid; h text; is_anon boolean; owner_pro boolean; cnt int;
begin
  me := public.bl_owner_id();
  if me is null then raise exception 'auth required'; end if;
  if coalesce(p_code, '') = '' then raise exception 'invalid invite'; end if;

  select family_id into fam from public.bl_family_member where invite_code = p_code limit 1;
  if fam is null then raise exception 'invalid invite'; end if;

  -- 이미 멤버면 비번/등급 검사 없이 통과(재방문)
  if exists (select 1 from public.bl_family_member where family_id = fam and uid = me) then
    return fam;
  end if;

  -- 가족 비밀번호가 설정돼 있으면 검증
  select join_pass_hash into h from public.bl_family where id = fam;
  if h is not null then
    if coalesce(p_pass, '') = '' or crypt(p_pass, h) <> h then
      raise exception 'wrong_password';
    end if;
  end if;

  -- ── 합류는 누구나 '승인 대기'로 ──
  -- 플랫폼(아이폰/안드로이드) 무관하게 일단 합류 신청만 받는다. 실제 인원·등급 제한
  -- (무료 2명=부부 / Pro 8명)은 '주인이 승인할 때' bl_approve_member에서 강제한다.
  is_anon := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);

  -- 합류(미사용 초대 행 claim → 없으면 새 멤버 행). 웹(익명)=조부모, 앱=부모.
  update public.bl_family_member
     set uid = me, joined_at = now(),
         role = case when is_anon then role else 'parent' end,
         display_name = coalesce(nullif(p_name, ''), display_name)
   where invite_code = p_code and uid is null;
  if not found then
    insert into public.bl_family_member (family_id, uid, role, display_name, joined_at)
    values (fam, me, case when is_anon then 'grandparent' else 'parent' end,
            coalesce(nullif(p_name, ''), '가족'), now());
  end if;
  return fam;
end;
$$;
grant execute on function public.bl_claim_invite(text, text, text) to anon, authenticated;

-- ════════════════ 멤버 삭제(나가기 / 내보내기) 정책 ════════════════
-- bl_family_member 에 DELETE 정책이 없으면 아무도 멤버 행을 지울 수 없다.
-- 규칙:
--   · 가족 주인(bl_family.owner_uid = bl_owner_id())은 자기 가족의 어떤 멤버든 삭제(내보내기) 가능.
--   · 멤버 본인(uid = bl_owner_id())은 자기 행만 삭제(스스로 나가기) 가능.
-- 멱등: 재실행 안전(기존 정책 drop 후 재생성).
drop policy if exists bl_member_delete on public.bl_family_member;
create policy bl_member_delete on public.bl_family_member for delete using (
  uid = public.bl_owner_id()
  or exists (select 1 from public.bl_family f where f.id = family_id and f.owner_uid = public.bl_owner_id())
);
