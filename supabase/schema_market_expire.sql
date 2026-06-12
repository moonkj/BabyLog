-- BabyLog · 마켓 30일 자동 만료 삭제 (pg_cron)
-- 무료 정책: 매물은 생성 +30일(expires_at)에 자동 삭제. 앱은 이미 fetch 시 expires_at > now() 만 노출하지만,
-- 실제 행/사진을 지우지 않으면 DB·Storage 비용이 무한 증가 → 매일 정리 잡으로 삭제.
-- schema_market.sql 적용 후 SQL Editor에서 1회 실행.

-- ───────── 만료 정리 함수(행 + 사진 객체) ─────────
-- security definer: cron 실행 롤이 storage.objects·market_item 삭제 권한을 갖도록.
-- 사진 경로는 photo_urls의 ".../market-photos/<경로>" 에서 <경로> 추출해 매칭.
create or replace function public.expire_market_items()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
begin
  -- 1) 만료 매물의 Storage 사진 객체 정리(대역폭·저장 비용 회수)
  delete from storage.objects o
  using public.market_item m, lateral unnest(m.photo_urls) as u(url)
  where m.expires_at < now()
    and o.bucket_id = 'market-photos'
    and o.name = split_part(u.url, '/market-photos/', 2);

  -- 2) 만료 매물 삭제(채팅·좋아요 등 FK on delete cascade로 함께 정리)
  delete from public.market_item where expires_at < now();
end $$;

-- ───────── 매일 03시(서버 UTC 기준) 실행 예약 ─────────
-- pg_cron 확장 먼저 활성화(없으면). cron.job 테이블 참조 전에 반드시 선행.
-- (안 되면 Dashboard → Database → Extensions 에서 pg_cron 켠 뒤 이 아래만 다시 실행)
create extension if not exists pg_cron;

-- 중복 등록 방지: 기존 동일 잡 제거 후 재등록
select cron.unschedule(jobid) from cron.job where jobname = 'market_expire';
select cron.schedule('market_expire', '0 3 * * *', $$select public.expire_market_items();$$);

-- 확인: select * from cron.job where jobname = 'market_expire';
-- 수동 1회 실행(테스트): select public.expire_market_items();
