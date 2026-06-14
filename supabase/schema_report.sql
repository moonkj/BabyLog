-- BabyLog · 신고(채팅/사용자/매물/게시글) — 운영자 전용 열람.
-- 누구나 제출(insert), 조회 정책 없음 → anon/auth 불가. 운영자는 Edge(admin-reports, service_role)로만 열람.
-- 증거 보존: 신고 시점 대화 스냅샷(transcript)을 함께 저장(분쟁/수사 대비).
create table if not exists public.bl_report (
  id            uuid primary key default gen_random_uuid(),
  reporter      text not null,                 -- 신고자(ownerID = auth.uid 또는 기기ID)
  reported      text,                          -- 신고 대상 식별자(authorId/seller 등)
  reported_name text,                          -- 신고 대상 표시명(닉네임)
  surface       text not null,                 -- market_chat / crew_meetup / crew_group / market_item / crew_post
  context_id    text,                          -- 매물/모임/그룹/글 id
  reason        text not null,
  note          text,
  transcript    jsonb not null default '[]',   -- 신고 시점 대화 스냅샷(증거)
  created_at    timestamptz not null default now()
);
create index if not exists bl_report_created_idx on public.bl_report (created_at desc);

alter table public.bl_report enable row level security;
drop policy if exists bl_report_ins on public.bl_report;
-- 제출만 허용(본인 명의). 조회/수정/삭제 정책 없음 → 운영자(service_role)만.
create policy bl_report_ins on public.bl_report for insert to anon, authenticated with check (
  reporter = coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id', ''))
);
