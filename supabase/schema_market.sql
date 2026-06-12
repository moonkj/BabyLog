-- BabyLog · 마켓(중고거래) 스키마 — 무료 티어
-- 정책: 1인 1매물(앱 단 게이트) · 30일 자동 만료 · 사진은 공개 상품 사진(아이 사진 아님) Storage 호스팅.
-- RLS는 크루와 동일한 전환기 패턴(읽기 개방 / 쓰기 본인). auth 도입 후 owner=auth.uid 강제(docs/AUTH_SETUP.md §5).
-- ⚠️ 마켓은 현재 피처 플래그(AppFeatures.market=false)로 숨김. 출시 전 이 스키마 실행.

create table if not exists public.market_item (
    id             uuid primary key default gen_random_uuid(),
    hood           text not null,
    title          text not null,
    category       text,
    grade          text,
    months_tag     text,
    price          int not null default 0,
    is_free        boolean not null default false,
    is_graduate    boolean not null default false,
    has_recall     boolean not null default false,
    description    text,
    hygiene_checks text[] default '{}',
    photo_urls     text[] default '{}',
    seller         text not null,                 -- 익명 기기 UUID 또는 auth.uid()
    seller_name    text,
    status         text not null default '판매중', -- 판매중/예약중/판매완료
    created_at     timestamptz not null default now(),
    expires_at     timestamptz not null default now() + interval '30 days'
);
create index if not exists market_item_hood_idx    on public.market_item (hood, created_at desc);
create index if not exists market_item_expires_idx on public.market_item (expires_at);
create index if not exists market_item_seller_idx  on public.market_item (seller);

alter table public.market_item enable row level security;
drop policy if exists market_item_all  on public.market_item;
drop policy if exists market_item_read on public.market_item;
drop policy if exists market_item_ins  on public.market_item;
drop policy if exists market_item_upd  on public.market_item;
drop policy if exists market_item_del  on public.market_item;
create policy market_item_read on public.market_item for select to anon, authenticated using (true);
create policy market_item_ins  on public.market_item for insert to anon, authenticated
  with check ( seller = coalesce(auth.uid()::text, seller) );
create policy market_item_upd  on public.market_item for update to anon, authenticated
  using ( seller = coalesce(auth.uid()::text, seller) ) with check ( seller = coalesce(auth.uid()::text, seller) );
create policy market_item_del  on public.market_item for delete to anon, authenticated
  using ( seller = coalesce(auth.uid()::text, seller) );

-- ───────── 30일 자동 만료 삭제 ─────────
-- pg_cron(권장): 매일 03시 만료분 + 그 사진 정리. (Edge Function 스케줄로 대체 가능)
--   create extension if not exists pg_cron;
--   select cron.schedule('market_expire','0 3 * * *',
--     $$delete from public.market_item where expires_at < now()$$);
-- 보조: 앱은 fetch 시 expires_at > now() 만 노출(아래 코드가 이미 필터).
-- 사진 객체 정리는 만료 삭제 트리거 또는 별도 잡으로(추후).

-- ───────── Storage 버킷(공개 상품 사진) ─────────
insert into storage.buckets (id, name, public)
  values ('market-photos','market-photos', true)
  on conflict (id) do nothing;

drop policy if exists market_photos_read on storage.objects;
drop policy if exists market_photos_ins  on storage.objects;
drop policy if exists market_photos_del  on storage.objects;
create policy market_photos_read on storage.objects for select to anon, authenticated
  using ( bucket_id = 'market-photos' );
create policy market_photos_ins  on storage.objects for insert to anon, authenticated
  with check ( bucket_id = 'market-photos' );
create policy market_photos_del  on storage.objects for delete to anon, authenticated
  using ( bucket_id = 'market-photos' );

-- ───────── 1:1 거래 채팅(매물 문의 대화) ─────────
-- 매물별 구매자↔판매자 대화. 개인정보 비저장: 익명 기기ID + 닉네임 + 본문.
-- RLS는 크루와 동일한 전환기 패턴(읽기 개방 / 쓰기·삭제 본인). auth 도입 후 device_id=auth.uid 강제.
create table if not exists public.market_chat_message (
    id          uuid primary key default gen_random_uuid(),
    item_id     uuid not null references public.market_item(id) on delete cascade,
    device_id   text not null,                 -- 익명 기기 UUID(작성자)
    author_name text,                          -- 표시용 닉네임(개인정보 아님)
    body        text not null,
    created_at  timestamptz not null default now()
);
create index if not exists market_chat_message_idx on public.market_chat_message (item_id, created_at);

alter table public.market_chat_message enable row level security;
drop policy if exists market_chat_message_read on public.market_chat_message;
drop policy if exists market_chat_message_ins  on public.market_chat_message;
drop policy if exists market_chat_message_del  on public.market_chat_message;
create policy market_chat_message_read on public.market_chat_message for select to anon, authenticated using (true);
create policy market_chat_message_ins  on public.market_chat_message for insert to anon, authenticated
  with check ( device_id = coalesce(auth.uid()::text, device_id) );
create policy market_chat_message_del  on public.market_chat_message for delete to anon, authenticated
  using ( device_id = coalesce(auth.uid()::text, device_id) );

-- ───────── 거래 신고(증거 보존, 운영자 전용 열람) ─────────
-- 신고 시점 대화 스냅샷을 서버에 보존(매물·채팅이 삭제돼도 증거 유지, 적법 절차 제출 대비).
-- ⚠️ 안전 설계: 누구나 INSERT(신고 제출), SELECT 정책 없음 → anon/authenticated 조회 불가.
--    운영자(service_role)만 RLS 우회로 열람. 신고 본문엔 대화·상대 표시명이 들어가므로 비공개 필수.
create table if not exists public.market_report (
    id           uuid primary key default gen_random_uuid(),
    item_id      text,                          -- 매물 id(로컬/서버 혼용)
    item_title   text,
    reporter     text not null,                 -- 익명 기기 UUID 또는 auth.uid()
    counterpart  text,                          -- 신고 대상 표시명
    reason       text not null,
    note         text,
    transcript   jsonb not null default '[]',   -- 신고 시점 대화 스냅샷(증거)
    created_at   timestamptz not null default now()
);
create index if not exists market_report_created_idx on public.market_report (created_at desc);

alter table public.market_report enable row level security;
drop policy if exists market_report_ins on public.market_report;
-- INSERT만 허용(누구나 신고). SELECT/UPDATE/DELETE 정책 없음 → 운영자(service_role)만 접근.
create policy market_report_ins on public.market_report for insert to anon, authenticated
  with check ( reporter = coalesce(auth.uid()::text, reporter) );
