-- schema_family_approval.sql
-- BabyLog · 가족 합류 '승인제' — 링크+비번으로 들어와도 곧바로 '승인 대기'.
-- 부모(주인)가 승인해야만 피드(사진·하트·댓글)를 볼 수 있다. 외부인이 링크·비번을 알아도
-- 주인 승인 없이는 아무것도 못 봄. 승인 인원 상한: 무료 2 / Pro 8.
-- 전제: schema_family_feed.sql, schema_family_invite.sql 적용됨. 멱등(재실행 안전).

-- ① 승인 컬럼 (신규 합류 = 기본 미승인)
alter table public.bl_family_member add column if not exists approved boolean not null default false;

-- 주인(가족 생성자) 행은 항상 승인 — 멱등.
update public.bl_family_member m
   set approved = true
  from public.bl_family f
 where f.id = m.family_id and f.owner_uid = m.uid and m.approved is distinct from true;
-- ⚠️ 기존(승인제 도입 전) 멤버는 미승인 상태가 되므로, 주인이 한 번 승인해 주면 된다.

-- ② 멤버 판정 = '승인된' 멤버 또는 주인 (피드 RLS의 근간)
--    미승인(대기)은 멤버로 안 침 → 피드/하트/댓글 전부 안 보임.
create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.bl_family_member m
    where m.family_id = p_family and m.uid = public.bl_owner_id() and m.approved
  ) or exists (
    select 1 from public.bl_family f
    where f.id = p_family and f.owner_uid = public.bl_owner_id()
  );
$$;

-- ③ 멤버 조회 정책 — 본인 행은 항상 보임(대기 상태 확인용), 승인 멤버/주인은 가족 전체 조회.
drop policy if exists bl_member_select on public.bl_family_member;
create policy bl_member_select on public.bl_family_member for select using (
  uid = public.bl_owner_id()
  or bl_is_family_member(family_id)
);

-- ④ 멤버 승인 — 주인만. 승인 인원 상한(무료 2 / Pro 8) 검사.
create or replace function public.bl_approve_member(p_member uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare fam uuid; owner_pro boolean; approved_cnt int; cap int;
begin
  select family_id into fam from public.bl_family_member where id = p_member;
  if fam is null then raise exception 'not found'; end if;
  if not exists (select 1 from public.bl_family f where f.id = fam and f.owner_uid = public.bl_owner_id()) then
    raise exception 'not owner';
  end if;
  select coalesce(p.is_pro, false) into owner_pro
    from public.bl_family f left join public.bl_profile p on p.uid = f.owner_uid where f.id = fam;
  cap := case when owner_pro then 8 else 2 end;
  select count(*) into approved_cnt
    from public.bl_family_member where family_id = fam and approved and uid is not null;
  if approved_cnt >= cap then raise exception 'family_full'; end if;
  update public.bl_family_member set approved = true where id = p_member;
end;
$$;
grant execute on function public.bl_approve_member(uuid) to anon, authenticated;
