-- schema_security_blockers.sql — 코드리뷰 출시 차단 보안 패치 (#1, #2)
-- ⚠️ 모든 스키마 적용 후, 그리고 이 파일 적용 후 schema_chat_push_hardening.sql을 '마지막'에 한 번 더 실행할 것(#5 순서 불변식).

-- ════════════ #2 가족 미디어 키 경로 제약 ════════════
-- bl_post_media.r2_key가 반드시 자기 family_id 경로(`<family_id>/...`)여야 함 — 다른 가족/임의 키 참조 차단.
drop policy if exists bl_media_insert on public.bl_post_media;
create policy bl_media_insert on public.bl_post_media for insert
  with check (
    public.bl_is_family_member(family_id)
    and r2_key like family_id::text || '/%'
  );

-- ════════════ #1 claim_device 기기→계정 배타 바인딩(콘텐츠 탈취 완화) ════════════
-- 문제: owner device UUID가 공개 조회 가능 → 수집 후 claim_device(피해자기기)로 소유권 탈취.
-- 완화: 한 번 어떤 계정이 귀속한 기기는 다른 계정이 재귀속 불가(이미 로그인·정리한 사용자 보호).
--   잔여(설계 한계): 한 번도 귀속 안 된 레거시 익명 기기의 '첫 귀속'은 막지 못함 — 로그인 의무화로
--   신규 콘텐츠는 auth.uid 소유라 노출면이 점차 0에 수렴. 완전 차단은 owner UUID 비노출 리팩터(후속).
create table if not exists public.claimed_device (
  device_id  text primary key,
  uid        text not null,
  claimed_at timestamptz not null default now()
);
alter table public.claimed_device enable row level security;   -- 정책 미부여 = 직접 접근 잠금(정의자 함수만)

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
  -- 배타 바인딩: 다른 계정이 이미 귀속한 기기면 아무 것도 하지 않음(탈취 차단). 같은 계정 재호출은 멱등 허용.
  if exists (select 1 from public.claimed_device c where c.device_id = p_device and c.uid <> auth.uid()::text) then
    return;
  end if;
  insert into public.claimed_device(device_id, uid) values (p_device, auth.uid()::text)
    on conflict (device_id) do nothing;

  update public.crew_post           set author    = auth.uid()::text where author    = p_device;
  update public.crew_post_reply     set author    = auth.uid()::text where author    = p_device;
  update public.crew_meetup         set host      = auth.uid()::text where host      = p_device;
  update public.crew_group          set creator   = auth.uid()::text where creator   = p_device;
  update public.crew_meetup_message set device_id = auth.uid()::text where device_id = p_device;
  update public.market_item         set seller    = auth.uid()::text where seller    = p_device;
  update public.market_chat_message set device_id = auth.uid()::text where device_id = p_device;
  update public.market_chat_message set buyer     = auth.uid()::text where buyer     = p_device;

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

-- ════════════ #5 검증(실행 후 확인) ════════════
-- market_chat_message read가 참가자 한정인지 확인(전체공개 using(true)면 안 됨):
--   select polname, qual from pg_policies where tablename='market_chat_message' and cmd='SELECT';
-- crew_rls를 다시 돌렸다면 반드시 schema_chat_push_hardening.sql을 마지막에 한 번 더 실행.
