-- BabyLog · 실시간 크루 오픈 푸시 (APNs)
-- schema.sql 적용 후 SQL Editor에서 실행.

-- ───────────────────────────────────────────────
-- 1) 푸시 토큰 (기기별 APNs 토큰 + 동네)
--    개인정보 없음: 익명 기기ID + APNs 토큰 + 동네명만.
-- ───────────────────────────────────────────────
create table if not exists public.crew_push_token (
    device_id   text primary key,                  -- 익명 기기 UUID
    apns_token  text not null,                     -- APNs device token (hex)
    hood        text,                              -- 현재 동네(역지오코딩)
    updated_at  timestamptz not null default now()
);
create index if not exists crew_push_token_hood_idx on public.crew_push_token (hood);

alter table public.crew_push_token enable row level security;

-- upsert(on_conflict) 허용 — FOR ALL(using/check true). SELECT 정책은 두지 않아 다른 기기 토큰 조회 불가
-- (anon에 토큰이 노출돼도 APNs 키가 없으면 무의미; 토큰 보호는 키로 보장).
-- ⚠️ 헤더 기반 USING 정책은 INSERT...ON CONFLICT DO UPDATE 에서 42501로 막히므로 사용하지 않음.
drop policy if exists crew_push_upsert on public.crew_push_token;
drop policy if exists crew_push_update on public.crew_push_token;
drop policy if exists crew_push_all on public.crew_push_token;
create policy crew_push_all on public.crew_push_token
    for all to anon, authenticated using (true) with check (true);

-- ───────────────────────────────────────────────
-- 2) 동네 오픈 상태 (중복 발송 방지 — 동네당 1회만 푸시)
-- ───────────────────────────────────────────────
create table if not exists public.crew_hood_status (
    hood        text primary key,
    opened      boolean not null default false,
    opened_at   timestamptz
);
alter table public.crew_hood_status enable row level security;
-- 읽기는 anon 허용(준비도/오픈 여부 확인용), 쓰기는 Edge Function(service_role)만
drop policy if exists crew_hood_status_read on public.crew_hood_status;
create policy crew_hood_status_read on public.crew_hood_status
    for select to anon, authenticated using (true);

-- ───────────────────────────────────────────────
-- 3) 자동 트리거: crew_waitlist INSERT 시 Database Webhook → Edge Function(notify-crew-open)
--    (대시보드 Database → Webhooks 로 설정 — docs/PUSH_SETUP.md 참고)
--    Edge Function이 count >= 목표 && not opened 이면 opened=true 처리 후 동네 토큰에 APNs 발송.
-- ───────────────────────────────────────────────
