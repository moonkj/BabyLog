-- schema_round1_hardening.sql — 반복 리뷰 Round 1 보완
-- ⚠️ 공유 프로젝트(bl_ 접두사). schema_family_invite.sql 이후 실행(최신 정의로 덮어쓰기).

-- 가족 합류(3-arg)에 '승인 대기' 행 상한 추가 — 초대코드를 안 외부인이 무제한 합류 신청을
-- 만들어 주인 승인 화면을 도배(DoS)·스토리지를 늘리는 것을 막는다. 정상 흐름(소수 초대)엔 영향 없음.
create or replace function public.bl_claim_invite(p_code text, p_name text, p_pass text)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare me text; fam uuid; h text; is_anon boolean; pending_cnt int;
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

  -- 승인 대기 행 상한(스팸/DoS 방지). 무료 2 / Pro 8 승인 + 대기 여유 포함.
  select count(*) into pending_cnt
    from public.bl_family_member where family_id = fam and coalesce(approved, false) = false;
  if pending_cnt >= 15 then raise exception 'too_many_pending'; end if;

  is_anon := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);

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
