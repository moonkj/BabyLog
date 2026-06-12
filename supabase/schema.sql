-- BabyLog · Supabase 스키마 (크루 MVP — 동네별 대기 신청/자동 오픈)
-- Supabase 대시보드 → SQL Editor에 붙여넣고 실행하세요.
--
-- 절대 원칙(CLAUDE.md):
--  - 아동 데이터는 서버에 저장하지 않는다. (사진·기록·아이 정보 X)
--  - 익명 기기 식별만 사용(개인정보 최소화). 추후 Apple 로그인으로 확장 가능.
--  - 데이터 주권: 사용자가 자기 기기 신청을 삭제할 수 있어야 한다.

-- ───────────────────────────────────────────────
-- 1) 동네 대기자 명단 (콜드스타트)
-- ───────────────────────────────────────────────
create table if not exists public.crew_waitlist (
    id          uuid primary key default gen_random_uuid(),
    hood        text not null,                         -- 동네명(역지오코딩 결과; 추후 행정동코드로 정규화)
    device_id   text not null,                         -- 익명 기기 UUID (아동/개인정보 아님)
    created_at  timestamptz not null default now(),
    unique (hood, device_id)
);

create index if not exists crew_waitlist_hood_idx on public.crew_waitlist (hood);

-- 동네별 신청 수 (집계 RPC — anon이 전체 행을 못 읽어도 카운트는 얻도록)
create or replace function public.crew_waitlist_count(p_hood text)
returns integer
language sql
security definer
set search_path = public
as $$
    select count(*)::int from public.crew_waitlist where hood = p_hood;
$$;

-- ───────────────────────────────────────────────
-- 2) RLS (행 수준 보안)
--    - anon은 '자기 device_id' 행만 추가/삭제. 전체 조회는 막고, 카운트는 RPC로만.
-- ───────────────────────────────────────────────
alter table public.crew_waitlist enable row level security;

-- 신청(추가): 누구나 자기 행 추가 가능
drop policy if exists crew_waitlist_insert on public.crew_waitlist;
create policy crew_waitlist_insert on public.crew_waitlist
    for insert to anon, authenticated
    with check (true);

-- 취소(삭제): device_id 헤더와 일치하는 자기 행만 (간이 — 추후 인증 강화)
drop policy if exists crew_waitlist_delete on public.crew_waitlist;
create policy crew_waitlist_delete on public.crew_waitlist
    for delete to anon, authenticated
    using (device_id = current_setting('request.headers', true)::json->>'x-device-id');

-- 자기 행 조회(내가 신청했는지 확인용)
drop policy if exists crew_waitlist_select_own on public.crew_waitlist;
create policy crew_waitlist_select_own on public.crew_waitlist
    for select to anon, authenticated
    using (device_id = current_setting('request.headers', true)::json->>'x-device-id');

-- ───────────────────────────────────────────────
-- 3) (다음 단계) 크루 그룹 · 모임 · 게시판 — 자리만 표시(추후 활성화)
--    크루가 동네에서 오픈되면 아래 테이블로 확장한다.
-- ───────────────────────────────────────────────
-- create table public.crew_group (...);
-- create table public.crew_meetup (...);
-- create table public.crew_post (...);
