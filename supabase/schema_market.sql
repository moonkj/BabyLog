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
