-- BabyLog · 크루장(그룹 개설자) 위임 RPC
-- 크루장이 탈퇴하면 다음 가입자에게 크루장을 넘긴다. crew_group update 정책의 with_check가
-- 'creator==본인'을 요구해 클라 PATCH로는 타인 위임이 불가 → security definer로 안전하게 처리.
-- 검증: 호출자(coalesce(auth.uid, x-device-id))가 현재 크루장 + 대상이 그룹 멤버일 때만 위임.

create or replace function public.crew_transfer_group(p_group uuid, p_to text)
returns boolean language plpgsql security definer
set search_path = public as $$
declare me text;
begin
  me := coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id', ''));
  if me is null then return false; end if;
  -- 현재 크루장만 위임 가능
  if not exists (select 1 from public.crew_group where id = p_group and creator = me) then
    return false;
  end if;
  -- 대상이 실제 그룹 멤버여야 함
  if not exists (select 1 from public.crew_group_member where group_id = p_group and device_id = p_to) then
    return false;
  end if;
  -- 위임: 새 크루장으로 변경. 표시명은 멤버 테이블에 없으므로 비워 두고(앱이 '나'/추후 갱신), 오표시 방지.
  update public.crew_group set creator = p_to, creator_name = null where id = p_group;
  return true;
end; $$;

grant execute on function public.crew_transfer_group(uuid, text) to anon, authenticated;
