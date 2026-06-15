-- schema_analytics.sql — 익명 접속 통계 (관리자 대시보드용)
-- 원칙: 집계 전용, 개인·아동 정보 없음. 기기당 하루 1행(ownerID = 로그인 uid / 비로그인 기기ID) + 날짜 + 버전뿐.
-- 쓰기는 RPC(bl_active_ping)만, 읽기/집계는 admin Edge(service_role + JWT 화이트리스트)만.
-- 시간대: KST(Asia/Seoul) 자정 경계 고정.

create table if not exists public.bl_active_ping (
  device_id   text not null,                       -- ownerID(로그인 Apple uid / 비로그인 기기ID)
  day         date not null,                       -- KST 접속일
  app_version text,
  os_version  text,
  created_at  timestamptz not null default now(),
  unique (device_id, day)
);
create index if not exists bl_active_ping_day_idx on public.bl_active_ping (day);
create index if not exists bl_active_ping_dev_idx on public.bl_active_ping (device_id);

alter table public.bl_active_ping enable row level security;
-- 정책 미부여 = 직접 접근 잠금. (쓰기는 아래 definer RPC, 읽기는 service_role Edge만)

-- ① 하루 1회 핑 — 앱 포그라운드 진입 시 호출(클라가 날짜 dedup, 서버도 unique로 이중 방지).
create or replace function public.bl_active_ping(p_app text default null, p_os text default null)
returns void language plpgsql security definer set search_path = public as $$
declare me text := public.bl_owner_id();
begin
  if me is null or me = '' then return; end if;
  insert into public.bl_active_ping(device_id, day, app_version, os_version)
  values (me, (now() at time zone 'Asia/Seoul')::date, left(p_app, 20), left(p_os, 20))
  on conflict (device_id, day) do update
    set app_version = coalesce(excluded.app_version, public.bl_active_ping.app_version),
        os_version  = coalesce(excluded.os_version,  public.bl_active_ping.os_version);
end;
$$;
grant execute on function public.bl_active_ping(text, text) to anon, authenticated;

-- ② 관리자 통계 집계 — p_exclude(운영자 device_id 배열)는 카운트에서 제외. service_role(Edge)만 호출.
create or replace function public.bl_admin_stats(p_year int, p_exclude text[] default '{}')
returns jsonb language sql stable security definer set search_path = public as $$
  with base as (
    select device_id, day, app_version
      from public.bl_active_ping
     where device_id <> all (coalesce(p_exclude, '{}'))
  ),
  k as (select (now() at time zone 'Asia/Seoul')::date as today),
  fs as (select device_id, min(day) as first_day from base group by device_id),
  life as (
    select f.device_id, f.first_day, max(b.day) as last_day
      from fs f join base b on b.device_id = f.device_id
     group by f.device_id, f.first_day
  )
  select jsonb_build_object(
    'today',   (select count(distinct device_id) from base, k where day = k.today),
    'week',    (select count(distinct device_id) from base, k where day >  k.today - 7),
    'month',   (select count(distinct device_id) from base, k where day >  k.today - 30),
    'year',    (select count(distinct device_id) from base where extract(year from day) = p_year),
    'allTime', (select count(*) from fs),
    'newToday',       (select count(*) from fs, k where first_day = k.today),
    'returningToday', (select count(distinct b.device_id) from base b, fs, k
                        where b.device_id = fs.device_id and b.day = k.today and fs.first_day < k.today),
    -- 리텐션(%) : 최초 접속 후 N일 이상 지난 기기 중, 첫날 이후(+N일~) 한 번이라도 재방문한 비율
    'retD1',  (select coalesce(round(100.0 * count(*) filter (where last_day >= first_day + 1)
                       / nullif(count(*) filter (where first_day <= k.today - 1), 0)), 0)::int
                 from life, k where first_day <= k.today - 1),
    'retD7',  (select coalesce(round(100.0 * count(*) filter (where last_day >= first_day + 7)
                       / nullif(count(*) filter (where first_day <= k.today - 7), 0)), 0)::int
                 from life, k where first_day <= k.today - 7),
    'retD30', (select coalesce(round(100.0 * count(*) filter (where last_day >= first_day + 30)
                       / nullif(count(*) filter (where first_day <= k.today - 30), 0)), 0)::int
                 from life, k where first_day <= k.today - 30),
    'versions', (select coalesce(jsonb_agg(jsonb_build_object('v', app_version, 'n', n) order by n desc), '[]'::jsonb)
                   from (select app_version, count(distinct device_id) n from base, k
                          where day > k.today - 30 and app_version is not null
                          group by app_version) t),
    'years', (select coalesce(jsonb_agg(distinct extract(year from day)::int order by extract(year from day)::int), '[]'::jsonb) from base)
  );
$$;
-- ⚠️ Postgres 함수는 기본 PUBLIC execute라 grant 안 해도 호출됨 → 명시적으로 회수하고 service_role만 허용.
--    (운영자 화이트리스트 강제는 Edge admin-action에서, 집계 함수 자체는 service_role 전용)
revoke execute on function public.bl_admin_stats(int, text[]) from public, anon, authenticated;
grant execute on function public.bl_admin_stats(int, text[]) to service_role;
