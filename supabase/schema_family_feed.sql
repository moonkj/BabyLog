-- schema_family_feed.sql
-- BabyLog · Pro 가족 피드(클라우드 가족 보관함). ⚠️ 아직 미배포.
-- ⚠️ 공유 Supabase 프로젝트(rqlfyumzmpmhupjtroid, cafeVibe·noisespot와 공용)이므로
--    모든 객체에 bl_ 접두사로 네임스페이스 — 타 앱 테이블과 충돌 방지(출시 전 전용 프로젝트 분리 권장).
-- 선행: Cloudflare R2(미디어), App Store 구독 검증(is_pro). docs/PRO_FAMILY_FEED.md.
-- 원칙: 가족 멤버만 접근(아동안전), 미디어 바이트는 R2(여기엔 키만), 텍스트·관계만 Postgres.

-- ── bl_profile (Pro 구독 상태 — verify-subscription Edge가 권위적으로 기록) ──
create table if not exists public.bl_profile (
  uid            text primary key,            -- auth.uid
  is_pro         boolean not null default false,
  pro_expires_at timestamptz,
  updated_at     timestamptz not null default now()
);
alter table public.bl_profile enable row level security;
-- 본인 프로필만 읽기. is_pro 쓰기는 service_role(Edge)만 — 클라이언트 위조 차단(정책 미부여).
create policy bl_profile_select_self on public.bl_profile for select using (uid = auth.uid()::text);

-- ── 멤버십 헬퍼 (SECURITY DEFINER로 RLS 재귀 회피) ─────────────────────
create or replace function public.bl_is_family_member(p_family uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.bl_family_member m
    where m.family_id = p_family and m.uid = auth.uid()::text
  );
$$;

-- ── bl_family ─────────────────────────────────────────────────────────
create table if not exists public.bl_family (
  id          uuid primary key default gen_random_uuid(),
  owner_uid   text not null,                 -- 생성자(Pro 부모) auth.uid
  name        text not null default '우리 가족',
  created_at  timestamptz not null default now()
);
alter table public.bl_family enable row level security;
create policy bl_family_select on public.bl_family for select using (bl_is_family_member(id));
create policy bl_family_insert on public.bl_family for insert with check (owner_uid = auth.uid()::text);
create policy bl_family_update on public.bl_family for update using (owner_uid = auth.uid()::text);
create policy bl_family_delete on public.bl_family for delete using (owner_uid = auth.uid()::text);

-- ── bl_family_member (조부모 초대 포함) ───────────────────────────────
create table if not exists public.bl_family_member (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.bl_family(id) on delete cascade,
  uid          text,                          -- 수락 전 null(초대코드만)
  invite_code  text unique,                   -- 초대 링크 토큰
  role         text not null default 'grandparent', -- parent | grandparent
  display_name text not null default '가족',
  joined_at    timestamptz
);
alter table public.bl_family_member enable row level security;
create index if not exists idx_bl_member_family on public.bl_family_member(family_id);
create policy bl_member_select on public.bl_family_member for select using (bl_is_family_member(family_id));
create policy bl_member_insert on public.bl_family_member for insert
  with check (exists (select 1 from public.bl_family f where f.id = family_id and f.owner_uid = auth.uid()::text));

-- ── bl_feed_post ──────────────────────────────────────────────────────
create table if not exists public.bl_feed_post (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.bl_family(id) on delete cascade,
  author_uid  text not null,
  child_label text,                           -- 비식별 표시명(예: '라온') — 민감정보 최소화
  caption     text,
  milestone   text,
  taken_at    timestamptz,
  created_at  timestamptz not null default now()
);
alter table public.bl_feed_post enable row level security;
create index if not exists idx_bl_post_family on public.bl_feed_post(family_id, created_at desc);
create policy bl_post_select on public.bl_feed_post for select using (bl_is_family_member(family_id));
create policy bl_post_insert on public.bl_feed_post for insert
  with check (author_uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_post_delete on public.bl_feed_post for delete using (author_uid = auth.uid()::text);

-- ── bl_post_media (바이트는 R2, 여기엔 키만) ──────────────────────────
create table if not exists public.bl_post_media (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id  uuid not null references public.bl_family(id) on delete cascade,
  kind       text not null,                   -- photo | video
  r2_key     text not null,                   -- R2 객체 키(추측불가 UUID 기반)
  thumb_key  text,
  width      int, height int, duration_s int, bytes bigint
);
alter table public.bl_post_media enable row level security;
create index if not exists idx_bl_media_post on public.bl_post_media(post_id);
create policy bl_media_select on public.bl_post_media for select using (bl_is_family_member(family_id));
create policy bl_media_insert on public.bl_post_media for insert with check (bl_is_family_member(family_id));

-- ── bl_reaction (양방향 하트) ─────────────────────────────────────────
create table if not exists public.bl_reaction (
  post_id    uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id  uuid not null references public.bl_family(id) on delete cascade,
  uid        text not null,
  kind       text not null default 'heart',
  created_at timestamptz not null default now(),
  primary key (post_id, uid, kind)
);
alter table public.bl_reaction enable row level security;
create policy bl_reaction_select on public.bl_reaction for select using (bl_is_family_member(family_id));
create policy bl_reaction_write  on public.bl_reaction for insert with check (uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_reaction_delete on public.bl_reaction for delete using (uid = auth.uid()::text);

-- ── bl_comment (양방향 댓글) ──────────────────────────────────────────
create table if not exists public.bl_comment (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.bl_feed_post(id) on delete cascade,
  family_id   uuid not null references public.bl_family(id) on delete cascade,
  uid         text not null,
  author_name text not null default '가족',
  text        text not null,
  created_at  timestamptz not null default now()
);
alter table public.bl_comment enable row level security;
create index if not exists idx_bl_comment_post on public.bl_comment(post_id, created_at);
create policy bl_comment_select on public.bl_comment for select using (bl_is_family_member(family_id));
create policy bl_comment_insert on public.bl_comment for insert with check (uid = auth.uid()::text and bl_is_family_member(family_id));
create policy bl_comment_delete on public.bl_comment for delete using (uid = auth.uid()::text);

-- ⚠️ 미디어 업로드는 Edge Function(media-upload-url)이 is_pro + 멤버십 확인 후
--    R2 presigned PUT URL을 발급한다. Postgres엔 키만 기록(바이트 미경유).
