-- BabyLog · 마켓(중고거래) 스키마 — 무료 티어
-- 정책: 1인 1매물(앱 단 게이트) · 30일 자동 만료 · 사진은 공개 상품 사진(아이 사진 아님) Storage 호스팅.
-- RLS는 크루와 동일한 전환기 패턴(읽기 개방 / 쓰기 본인). auth 도입 후 owner=auth.uid 강제(docs/AUTH_SETUP.md §5).
-- ⚠️ 마켓은 현재 피처 플래그(AppFeatures.market=false)로 숨김. 출시 전 이 스키마 실행.

create table if not exists public.market_item (
    id             uuid primary key default gen_random_uuid(),
    hood           text not null,                 -- 판매자 동(표시용)
    city           text,                          -- 노출 범위(시/군) — 마켓은 시 단위 조회
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
-- 기존 테이블에 city 컬럼이 없으면 추가(멱등)
alter table public.market_item add column if not exists city text;
-- 양쪽 확인 거래: 판매자가 지정한 구매자(sold_to) + 구매자 확인(buyer_confirmed)
alter table public.market_item add column if not exists sold_to text;
alter table public.market_item add column if not exists buyer_confirmed boolean not null default false;
create index if not exists market_item_hood_idx    on public.market_item (hood, created_at desc);
create index if not exists market_item_city_idx    on public.market_item (city, created_at desc);
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

-- ───────── 1:1 거래 채팅(매물별 구매자↔판매자 1:1 스레드) ─────────
-- ⚠️ 공개방 아님: 스레드 키 = (item_id, buyer). 그 대화의 '해당 구매자'와 '그 매물 판매자'만 열람.
-- 개인정보 비저장: 익명 기기ID/auth.uid + 닉네임 + 본문.
-- 증거 보존: 메시지는 사용자가 삭제 불가(delete 정책 없음). 운영자는 service_role로 RLS 우회해
--   전체 열람·내보내기 가능(수사기관 제출). 신고 시점 스냅샷은 market_report(운영자 전용)에 별도 보존.
-- 기존 테이블이 있으면 buyer 컬럼만 추가(create-or-alter 양쪽 지원).
create table if not exists public.market_chat_message (
    id          uuid primary key default gen_random_uuid(),
    item_id     uuid not null references public.market_item(id) on delete cascade,
    buyer       text,                          -- 1:1 스레드의 구매자 측 식별(기기ID 또는 auth.uid)
    device_id   text not null,                 -- 작성자(구매자 또는 판매자)
    author_name text,                          -- 표시용 닉네임(개인정보 아님)
    body        text not null,
    created_at  timestamptz not null default now()
);
alter table public.market_chat_message add column if not exists buyer text;
create index if not exists market_chat_message_thread_idx on public.market_chat_message (item_id, buyer, created_at);

alter table public.market_chat_message enable row level security;
drop policy if exists market_chat_message_read on public.market_chat_message;
drop policy if exists market_chat_message_ins  on public.market_chat_message;
drop policy if exists market_chat_message_del  on public.market_chat_message;
-- 읽기: 해당 구매자 본인 OR 그 매물의 판매자만. (운영자 service_role은 RLS 우회 → 전체 열람)
create policy market_chat_message_read on public.market_chat_message for select to anon, authenticated using (
  buyer = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  or exists (
    select 1 from public.market_item mi
    where mi.id = item_id
      and mi.seller = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  )
);
-- 쓰기: 작성자 본인 표식 + (구매자 본인 OR 그 매물 판매자)일 때만
create policy market_chat_message_ins on public.market_chat_message for insert to anon, authenticated with check (
  device_id = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  and (
    buyer = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
    or exists (
      select 1 from public.market_item mi
      where mi.id = item_id
        and mi.seller = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
    )
  )
);
-- delete 정책 없음(의도적): 사용자는 메시지 삭제 불가 → 증거 보존. 운영자(service_role)만 정리 가능.

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

-- ───────── 거래 확인(구매자) ─────────
-- 판매자가 sold_to=구매자로 '판매완료'하면, 그 구매자만 buyer_confirmed=true로 확정 가능.
-- 컬럼 단위 권한 대신 security definer 함수로 안전하게(다른 필드 위조 차단).
create or replace function public.market_confirm_trade(p_item uuid)
returns boolean language plpgsql security definer as $$
declare me text;
begin
  me := coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id',''));
  update public.market_item
     set buyer_confirmed = true
   where id = p_item and sold_to = me and status = '판매완료';
  return found;
end; $$;
grant execute on function public.market_confirm_trade(uuid) to anon, authenticated;
