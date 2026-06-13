-- BabyLog · 인증(익명→Apple 로그인) 마이그레이션 — v2
-- v1 대비 변경: ① 마켓 테이블(market_item·market_chat_message) 포함 — 로그인 후 기존 매물
--   관리 불가/1매물 제한 우회 버그 수정 ② 좋아요/참가/멤버십 충돌을 행 단위로 병합
--   (v1은 PK 충돌 1건에 테이블 전체 마이그레이션이 롤백되던 버그).
-- ⚠️ 이미 v1을 실행했어도 그대로 다시 실행하면 됨(create or replace).
-- 자세한 배경: docs/AUTH_SETUP.md

create or replace function public.claim_device(p_device text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or p_device is null or p_device = '' then
    return;
  end if;

  -- 글/모임/그룹/매물: owner 컬럼 단순 귀속(충돌 없음 — PK가 id)
  update public.crew_post           set author    = auth.uid()::text where author    = p_device;
  update public.crew_post_reply     set author    = auth.uid()::text where author    = p_device;
  update public.crew_meetup         set host      = auth.uid()::text where host      = p_device;
  update public.crew_group          set creator   = auth.uid()::text where creator   = p_device;
  update public.crew_meetup_message set device_id = auth.uid()::text where device_id = p_device;
  update public.market_item         set seller    = auth.uid()::text where seller    = p_device;
  update public.market_chat_message set device_id = auth.uid()::text where device_id = p_device;
  -- 스레드 키(buyer)도 함께 귀속 — 누락 시 buyer가 기기ID로 남아 로그인한 구매자가
  -- 자기 채팅 스레드(RLS: buyer = auth.uid())를 못 보는 버그가 생긴다.
  update public.market_chat_message set buyer     = auth.uid()::text where buyer     = p_device;

  -- 좋아요/참가/멤버십: (대상, device_id) 복합 PK → 두 신원 모두 행이 있으면 병합(중복은 버림).
  -- v1처럼 UPDATE+exception 방식은 충돌 1건에 테이블 전체가 스킵되므로 insert-select+delete로 행 단위 처리.
  insert into public.crew_post_like (post_id, device_id)
    select post_id, auth.uid()::text from public.crew_post_like where device_id = p_device
    on conflict (post_id, device_id) do nothing;
  delete from public.crew_post_like where device_id = p_device;

  insert into public.crew_meetup_join (meetup_id, device_id, joined_at)
    select meetup_id, auth.uid()::text, joined_at from public.crew_meetup_join where device_id = p_device
    on conflict (meetup_id, device_id) do nothing;
  delete from public.crew_meetup_join where device_id = p_device;

  insert into public.crew_group_member (group_id, device_id, joined_at)
    select group_id, auth.uid()::text, joined_at from public.crew_group_member where device_id = p_device
    on conflict (group_id, device_id) do nothing;
  delete from public.crew_group_member where device_id = p_device;
end $$;

grant execute on function public.claim_device(text) to authenticated;

-- ───────────────────────────────────────────────
-- 소유자 기반 RLS는 schema_crew_rls.sql 참고(이미 적용됨).
-- 이 함수는 로그인 직후 앱(AuthStore.claimDevice)이 1회 호출한다.
-- ───────────────────────────────────────────────
