-- BabyLog · 크루 콘텐츠 스키마 (그룹 · 모임 · 게시판)
-- 동네 크루가 오픈된 뒤 실제 데이터. 익명 기기ID 기반(아동·개인정보 비저장).
-- 카운트(멤버/참가/좋아요)는 앱에서 count 쿼리로 표시(트리거 없이 단순).

-- ───────── 그룹 ─────────
create table if not exists public.crew_group (
    id           uuid primary key default gen_random_uuid(),
    hood         text not null,
    name         text not null,
    age_range    text,
    interest_tags text[] default '{}',
    creator      text not null,            -- 익명 기기 UUID
    creator_name text,                      -- 표시용 닉네임(개인정보 아님)
    created_at   timestamptz not null default now()
);
create index if not exists crew_group_hood_idx on public.crew_group (hood);
alter table public.crew_group add column if not exists creator_name text;

create table if not exists public.crew_group_member (
    group_id   uuid not null references public.crew_group(id) on delete cascade,
    device_id  text not null,
    joined_at  timestamptz not null default now(),
    primary key (group_id, device_id)
);

-- ───────── 모임 ─────────
create table if not exists public.crew_meetup (
    id          uuid primary key default gen_random_uuid(),
    hood        text not null,
    title       text not null,
    place       text,
    when_text   text,
    meetup_type text,                       -- park / indoor
    capacity    int not null default 8,
    host        text not null,              -- 익명 기기 UUID
    host_name   text,                       -- 표시용 닉네임(개인정보 아님)
    created_at  timestamptz not null default now()
);
create index if not exists crew_meetup_hood_idx on public.crew_meetup (hood);
alter table public.crew_meetup add column if not exists host_name text;

create table if not exists public.crew_meetup_join (
    meetup_id  uuid not null references public.crew_meetup(id) on delete cascade,
    device_id  text not null,
    joined_at  timestamptz not null default now(),
    primary key (meetup_id, device_id)
);

-- 모임 그룹 채팅 (참가자 대화). 개인정보 비저장: 익명 기기ID + 닉네임 + 본문.
create table if not exists public.crew_meetup_message (
    id          uuid primary key default gen_random_uuid(),
    meetup_id   uuid not null references public.crew_meetup(id) on delete cascade,
    device_id   text not null,                 -- 익명 기기 UUID(작성자)
    author_name text,                          -- 표시용 닉네임(개인정보 아님)
    body        text not null,
    created_at  timestamptz not null default now()
);
create index if not exists crew_meetup_message_idx on public.crew_meetup_message (meetup_id, created_at);

-- 또래 그룹 채팅 (가입자 대화). 개인정보 비저장: 익명 기기ID + 닉네임 + 본문.
create table if not exists public.crew_group_message (
    id          uuid primary key default gen_random_uuid(),
    group_id    uuid not null references public.crew_group(id) on delete cascade,
    device_id   text not null,
    author_name text,
    body        text not null,
    created_at  timestamptz not null default now()
);
create index if not exists crew_group_message_idx on public.crew_group_message (group_id, created_at);

-- ───────── 게시판 ─────────
create table if not exists public.crew_post (
    id          uuid primary key default gen_random_uuid(),
    hood        text not null,
    category    text not null default 'info',  -- info/together/qna
    author      text not null,                 -- 익명 기기 UUID
    author_name text,
    title       text not null,
    body        text,
    created_at  timestamptz not null default now()
);
create index if not exists crew_post_hood_idx on public.crew_post (hood, created_at desc);

create table if not exists public.crew_post_like (
    post_id    uuid not null references public.crew_post(id) on delete cascade,
    device_id  text not null,
    primary key (post_id, device_id)
);

create table if not exists public.crew_post_reply (
    id         uuid primary key default gen_random_uuid(),
    post_id    uuid not null references public.crew_post(id) on delete cascade,
    author     text not null,
    author_name text,
    body       text not null,
    created_at timestamptz not null default now()
);
create index if not exists crew_post_reply_idx on public.crew_post_reply (post_id, created_at);

-- ───────── RLS ─────────
-- 동네 커뮤니티: 읽기는 모두 허용, 쓰기는 익명 누구나(앱 단에서 device 기준 제어).
-- (출시 전 MVP. 추후 Apple 로그인 + 본인 글만 수정/삭제로 강화.)
do $$
declare t text;
begin
  foreach t in array array[
    'crew_group','crew_group_member','crew_meetup','crew_meetup_join',
    'crew_meetup_message','crew_group_message','crew_post','crew_post_like','crew_post_reply'
  ] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists %I_all on public.%I;', t, t);
    execute format(
      'create policy %I_all on public.%I for all to anon, authenticated using (true) with check (true);',
      t, t);
  end loop;
end $$;
