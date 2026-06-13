-- schema_family_feed.sql
-- BabyLog · Pro 가족 피드(클라우드 가족 보관함). ⚠️ 아직 미배포(설계 단계).
-- ⚠️ 공유 Supabase 프로젝트(rqlfyumzmpmhupjtroid, cafeVibe·noisespot 공용)이므로
--    모든 객체에 bl_ 접두사로 네임스페이스 — 타 앱과 충돌 방지(출시 전 전용 프로젝트 분리 권장).
-- 멱등: 테이블=if not exists, 함수=create or replace, 정책=drop if exists 후 create → 재실행 안전.
-- 순서: ① 테이블 전부 → ② 헬퍼 함수(테이블 참조하므로 뒤에) → ③ RLS 정책.

-- ════════════════ ① 테이블 ════════════════

create table if not exists public.bl_profile (
  uid            text primary key,
  is_pro         boolean not null default false,
  pro_expires_at timestamptz,
  updated_at     timestamptz not null default now()
);

create table if not exists public.bl_family (
  id          uuid primary key default gen_random_uuid(),
  owner_uid   text not null,
  name        text not null default '우리 가족',
  created_at  timestamptz not null default now()
);

create table if not exists public.bl_family_member (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.bl_family(id) on delete cascade,
  uid          text,
  invite_code  text unique,
  role         text not null default 'grandparent',  -- parent | grandparent
  display_name text not null default '가족',
  joined_at    timestamptz
);

create table if not exists public.bl_feed_post (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.bl_family(id) on delete cascade,
  author_uid  text not null,
  child_label text,
  caption     text,
  milestone   text,
  taken_at    timestamptz,
  created_at  timestamptz not null default now()
);

create table if not exists public.bl_post_media (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id  uuid not null references public.bl_family(id) on delete cascade,
  kind       text not null,                  -- photo | video
  r2_key     text not null,
  thumb_key  text,
  width      int, height int, duration_s int, bytes bigint
);

create table if not exists public.bl_reaction (
  post_id    uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id  uuid not null references public.bl_family(id) on delete cascade,
  uid        text not null,
  kind       text not null default 'heart',
  created_at timestamptz not null default now(),
  primary key (post_id, uid, kind)
);

create table if not exists public.bl_comment (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id   uuid not null references public.bl_family(id) on delete cascade,
  uid         text not null,
  author_name text not null default '가족',
  text        text not null,
  created_at  timestamptz not null default now()
);

-- 인덱스
create index if not exists idx_bl_member_family on public.bl_family_member(family_id);
create index if not exists idx_bl_post_family   on public.bl_feed_post(family_id, created_at desc);
create index if not exists idx_bl_media_post    on public.bl_post_media(post_id);
create index if not exists idx_bl_comment_post  on public.bl_comment(post_id, created_at);

-- RLS 활성화(멱등)
alter table public.bl_profile       enable row level security;
alter table public.bl_family        enable row level security;
alter table public.bl_family_member enable row level security;
alter table public.bl_feed_post     enable row level security;
alter table public.bl_post_media    enable row level security;
alter table public.bl_reaction      enable row level security;
alter table public.bl_comment       enable row level security;

-- ════════════════ ② 헬퍼 함수 (테이블 생성 후) ════════════════

create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.bl_family_member m
    where m.family_id = p_family and m.uid = auth.uid()::text
  );
$$;

-- ════════════════ ③ RLS 정책 (drop if exists → create, 재실행 안전) ════════════════

-- bl_profile: 본인만 읽기. is_pro 쓰기는 service_role(Edge)만(정책 미부여 → 클라 위조 차단).
drop policy if exists bl_profile_select_self on public.bl_profile;
create policy bl_profile_select_self on public.bl_profile for select using (uid = auth.uid()::text);

-- bl_family
drop policy if exists bl_family_select on public.bl_family;
drop policy if exists bl_family_insert on public.bl_family;
drop policy if exists bl_family_update on public.bl_family;
drop policy if exists bl_family_delete on public.bl_family;
create policy bl_family_select on public.bl_family for select using (bl_is_family_member(id));
create policy bl_family_insert on public.bl_family for insert with check (owner_uid = auth.uid()::text);
create policy bl_family_update on public.bl_family for update using (owner_uid = auth.uid()::text);
create policy bl_family_delete on public.bl_family for delete using (owner_uid = auth.uid()::text);

-- bl_family_member
drop policy if exists bl_member_select on public.bl_family_member;
drop policy if exists bl_member_insert on public.bl_family_member;
create policy bl_member_select on public.bl_family_member for select using (bl_is_family_member(family_id));
create policy bl_member_insert on public.bl_family_member for insert
  with check (exists (select 1 from public.bl_family f where f.id = family_id and f.owner_uid = auth.uid()::text));

-- bl_feed_post
drop policy if exists bl_post_select on public.bl_feed_post;
drop policy if exists bl_post_insert on public.bl_feed_post;
drop policy if exists bl_post_delete on public.bl_feed_post;
create policy bl_post_select on public.bl_feed_post for select using (bl_is_family_member(family_id));
create policy bl_post_insert on public.bl_feed_post for insert
  with check (author_uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_post_delete on public.bl_feed_post for delete using (author_uid = auth.uid()::text);

-- bl_post_media
drop policy if exists bl_media_select on public.bl_post_media;
drop policy if exists bl_media_insert on public.bl_post_media;
create policy bl_media_select on public.bl_post_media for select using (bl_is_family_member(family_id));
create policy bl_media_insert on public.bl_post_media for insert with check (bl_is_family_member(family_id));

-- bl_reaction
drop policy if exists bl_reaction_select on public.bl_reaction;
drop policy if exists bl_reaction_write  on public.bl_reaction;
drop policy if exists bl_reaction_delete on public.bl_reaction;
create policy bl_reaction_select on public.bl_reaction for select using (bl_is_family_member(family_id));
create policy bl_reaction_write  on public.bl_reaction for insert with check (uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_reaction_delete on public.bl_reaction for delete using (uid = auth.uid()::text);

-- bl_comment
drop policy if exists bl_comment_select on public.bl_comment;
drop policy if exists bl_comment_insert on public.bl_comment;
drop policy if exists bl_comment_delete on public.bl_comment;
create policy bl_comment_select on public.bl_comment for select using (bl_is_family_member(family_id));
create policy bl_comment_insert on public.bl_comment for insert with check (uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_comment_delete on public.bl_comment for delete using (uid = auth.uid()::text);

-- ⚠️ 미디어 업로드는 Edge Function(media-upload-url)이 is_pro + 멤버십 확인 후
--    R2 presigned PUT URL을 발급한다. Postgres엔 키만 기록(바이트 미경유).
