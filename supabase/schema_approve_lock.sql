-- schema_approve_lock.sql — 승인 캡(무료2/Pro8) 레이스 방지 (HIGH)
-- 동시 bl_approve_member 호출이 count를 같은 값으로 읽어 캡을 넘기던 read-then-write 레이스를
-- 가족 단위 advisory lock으로 직렬화. (schema_family_partner.sql과 동일 — 최신본으로 갱신)

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
  -- 가족 단위 직렬화 — 동시 승인 캡 우회 방지.
  perform pg_advisory_xact_lock(hashtext(fam::text));
  select coalesce(p.is_pro, false) into owner_pro
    from public.bl_family f left join public.bl_profile p on p.uid = f.owner_uid where f.id = fam;
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
