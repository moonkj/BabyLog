-- schema_family_partner.sql — 무료 '배우자' 명시 지정
-- 문제: Pro로 여러 명(배우자+조부모) 승인 후 구독 만료 시, 무료 1명을 '가장 먼저 승인된 사람'
--       으로 추정하면 배우자가 아니라 조부모가 살아남을 수 있다(누가 배우자인지 모름).
-- 해결: 주인이 무료 배우자(만료 시 유지될 1명)를 명시 지정(bl_family.partner_uid).
--       첫 비주인 승인 시 자동 지정(평소엔 손 안 가게) + 주인이 언제든 재지정.
-- ⚠️ 공유 프로젝트 — 모든 객체 bl_ 접두사. schema_family_approval.sql 이후 실행.

-- ① 지정 컬럼
alter table public.bl_family add column if not exists partner_uid text;

-- ② 멤버 판정 — 비구독 시 무료 배우자는 '명시 지정(partner_uid)' 우선, 미지정/무효면 가장 먼저 승인된 비주인.
create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language plpgsql security definer stable as $$
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
    -- 지정이 없거나(레거시) 지정자가 더 이상 승인 멤버가 아니면 → 가장 먼저 승인된 비주인으로 폴백.
    select uid into partner from public.bl_family_member
     where family_id = p_family and approved and uid <> owner
     order by joined_at asc nulls last, id asc limit 1;
  end if;
  return me = partner;
end;
$$;
grant execute on function public.bl_is_family_member(uuid) to anon, authenticated;

-- ③ 승인 시 무료 배우자 자동 지정(미지정 상태에서 첫 비주인 승인 → 그 사람을 배우자로).
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
  select coalesce(p.is_pro, false) into owner_pro
    from public.bl_family f left join public.bl_profile p on p.uid = f.owner_uid where f.id = fam;
  select count(*) into approved_cnt
    from public.bl_family_member where family_id = fam and approved and uid is not null;
  -- 무료 = 부부 2명(플랫폼 무관). 그 이상(조부모·친척)은 Pro. Pro 상한 8명.
  if not owner_pro and approved_cnt >= 2 then raise exception 'needs_pro'; end if;
  if owner_pro and approved_cnt >= 8 then raise exception 'family_full'; end if;
  update public.bl_family_member set approved = true where id = p_member;
  -- 무료 배우자 자동 지정: 미지정 + 비주인 + uid 있음.
  if muid is not null then
    update public.bl_family f set partner_uid = muid
     where f.id = fam and f.partner_uid is null and muid <> f.owner_uid;
  end if;
end;
$$;
grant execute on function public.bl_approve_member(uuid) to anon, authenticated;

-- ④ 주인이 무료 배우자를 명시 재지정(승인된 멤버만 가능).
create or replace function public.bl_set_partner(p_member uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare fam uuid; muid text;
begin
  select family_id, uid into fam, muid from public.bl_family_member where id = p_member and approved;
  if fam is null then raise exception 'not found or not approved'; end if;
  if not exists (select 1 from public.bl_family f where f.id = fam and f.owner_uid = public.bl_owner_id()) then
    raise exception 'not owner';
  end if;
  if muid is null then raise exception 'no uid'; end if;
  update public.bl_family set partner_uid = muid where id = fam;
end;
$$;
grant execute on function public.bl_set_partner(uuid) to anon, authenticated;
