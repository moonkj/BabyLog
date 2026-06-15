-- schema_launch_hardening.sql — 출시 전 보안 하드닝 (리뷰 차단 이슈 #1, #3)
-- 1) bl_dev_set_pro 백도어 제거: anon이 자기 is_pro를 위조해 Pro를 무단 활성화하던 RPC 삭제.
--    Pro 등급은 StoreKit 영수증 검증(verify-subscription, service_role)만 bl_profile.is_pro를 쓴다.
-- 3) bl_is_family_member(RLS 핵심)에 search_path 고정: 공유 프로젝트에서 search_path 미고정은
--    권한상승 벡터. 다른 정의자 함수와 동일하게 `set search_path = public`을 붙인다.
-- ⚠️ schema_family_partner.sql 이후 실행(가장 최신 정의를 덮어쓴다).

-- 1) 백도어 제거
drop function if exists public.bl_dev_set_pro(boolean);

-- 3) bl_is_family_member 재생성(search_path 고정)
create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language plpgsql security definer stable
set search_path = public as $$
declare me text; owner text; owner_pro boolean; partner text;
begin
  me := public.bl_owner_id();
  if me is null then return false; end if;
  select f.owner_uid, coalesce(p.is_pro, false), f.partner_uid into owner, owner_pro, partner
    from public.bl_family f left join public.bl_profile p on p.uid = f.owner_uid
   where f.id = p_family;
  if owner is null then return false; end if;
  if owner = me then return true; end if;                  -- 주인은 항상
  if not exists (select 1 from public.bl_family_member
                  where family_id = p_family and uid = me and approved) then
    return false;                                          -- 미승인/비멤버
  end if;
  if owner_pro then return true; end if;                   -- 구독 중 → 모든 승인 멤버
  -- 비구독: 무료 배우자 1명만 유지.
  if partner is null or not exists (
        select 1 from public.bl_family_member
         where family_id = p_family and uid = partner and approved and uid <> owner) then
    select uid into partner from public.bl_family_member
     where family_id = p_family and approved and uid <> owner
     order by joined_at asc nulls last, id asc limit 1;
  end if;
  return me = partner;
end;
$$;
grant execute on function public.bl_is_family_member(uuid) to anon, authenticated;
