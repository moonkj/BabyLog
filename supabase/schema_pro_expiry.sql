-- schema_pro_expiry.sql — 구독 만료를 서버 게이트에 반영 (CRITICAL)
-- 문제: 게이트들이 bl_profile.is_pro(불리언)만 보고 pro_expires_at를 무시해서,
--       구독 만료/해지 후에도 조부모 열람·8인 초대·영상 300이 무기한 유지됐다.
-- 해결: 만료까지 함께 보는 헬퍼 bl_pro_active()로 일원화하고, 가족 멤버 판정·승인 캡·영상 캡을 재정의.
-- ⚠️ 공유 프로젝트 — 모든 객체 bl_ 접두사. 이 파일을 가족/승인/영상 관련 SQL '이후, 맨 마지막'에 실행해
--    만료 인지 버전이 최종으로 적용되게 한다(create or replace 덮어쓰기).

-- ① 만료 인지 Pro 판정 — is_pro AND (만료없음 OR 미래만료). 프로필 없으면 false.
create or replace function public.bl_pro_active(p_uid text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select p.is_pro and (p.pro_expires_at is null or p.pro_expires_at > now())
       from public.bl_profile p where p.uid = p_uid), false);
$$;
grant execute on function public.bl_pro_active(text) to anon, authenticated;

-- ② 가족 멤버 판정 — 비구독(또는 만료) 시 무료 배우자 1명만 유지. (schema_family_partner.sql 최신본 + 만료반영)
create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language plpgsql security definer stable
set search_path = public as $$
declare me text; owner text; owner_pro boolean; partner text;
begin
  me := public.bl_owner_id();
  if me is null then return false; end if;
  select f.owner_uid, public.bl_pro_active(f.owner_uid), f.partner_uid
    into owner, owner_pro, partner
    from public.bl_family f where f.id = p_family;
  if owner is null then return false; end if;
  if owner = me then return true; end if;                  -- 주인은 항상
  if not exists (select 1 from public.bl_family_member
                  where family_id = p_family and uid = me and approved) then
    return false;                                          -- 미승인/비멤버
  end if;
  if owner_pro then return true; end if;                   -- 구독 유효 → 모든 승인 멤버
  -- 비구독/만료: 무료 배우자 1명만 유지(명시 partner 우선, 없으면 가장 먼저 승인된 비주인).
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

-- ③ 멤버 승인 캡 — 무료 2 / Pro 8. owner_pro를 만료반영 판정으로. (schema_approve_lock.sql + 만료반영)
create or replace function public.bl_approve_member(p_member uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare fam uuid; muid text; owner_pro boolean; approved_cnt int;
begin
  select family_id, uid into fam, muid from public.bl_family_member where id = p_member;
  if fam is null then raise exception 'not found'; end if;
  if not exists (select 1 from public.bl_family f where f.id = fam and f.owner_uid = public.bl_owner_id()) then
    raise exception 'not owner';
  end if;
  perform pg_advisory_xact_lock(hashtext(fam::text));   -- 동시 승인 캡 우회 방지
  select public.bl_pro_active(f.owner_uid) into owner_pro
    from public.bl_family f where f.id = fam;
  select count(*) into approved_cnt
    from public.bl_family_member where family_id = fam and approved and uid is not null;
  if not owner_pro and approved_cnt >= 2 then raise exception 'needs_pro'; end if;
  if owner_pro and approved_cnt >= 8 then raise exception 'family_full'; end if;
  update public.bl_family_member set approved = true where id = p_member;
  if muid is not null then
    update public.bl_family f set partner_uid = muid
     where f.id = fam and f.partner_uid is null and muid <> f.owner_uid;
  end if;
end;
$$;
grant execute on function public.bl_approve_member(uuid) to anon, authenticated;

-- ④ 영상 캡 — 무료 100 / Pro 300. 만료반영. (schema_video_cap.sql + 만료반영)
create or replace function public.bl_video_cap(p_family uuid)
returns int language sql stable security definer set search_path = public
as $$
  select case when public.bl_pro_active(f.owner_uid) then 300 else 100 end
    from public.bl_family f where f.id = p_family;
$$;
grant execute on function public.bl_video_cap(uuid) to anon, authenticated;
