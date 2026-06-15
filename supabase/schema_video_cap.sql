-- schema_video_cap.sql — 가족 영상 상한(무료 100 / Pro 300)
-- 카운터 표시용. 주인 is_pro 기준이며, bl_profile RLS(본인만 읽기) 때문에
-- 비주인 멤버(배우자 등)는 주인 is_pro를 직접 못 읽는다 → SECURITY DEFINER로 캡만 노출.
-- 실제 업로드 차단(강제)은 Edge media-upload-url(service_role)이 동일 로직으로 수행.

create or replace function public.bl_video_cap(p_family uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select case when coalesce(p.is_pro, false) then 300 else 100 end
    from public.bl_family f
    left join public.bl_profile p on p.uid = f.owner_uid
   where f.id = p_family;
$$;

grant execute on function public.bl_video_cap(uuid) to anon, authenticated;
