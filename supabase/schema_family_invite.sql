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
