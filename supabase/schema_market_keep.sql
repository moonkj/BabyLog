-- schema_market_keep.sql
-- 마켓 매물 자동삭제(30일 만료) 중단 — 매물을 만료로 지우지 않고 유지.
--   배경: schema_market_expire.sql이 매일 03시 cron으로 expires_at 지난 매물(행+사진)을 삭제했다.
--         이제 매물은 '판매완료/판매자 직접 삭제'까지 유지한다(이력 누적 정리는 추후 별도 기능으로).
--   앱: 조회 시 expires_at 필터 제거(MarketBackend) — 30일 지난 매물도 계속 노출.
-- 실행: Supabase SQL Editor에서 1회. (멱등 — 잡이 없으면 아무 일 없음)

-- 1) 자동 만료 삭제 cron 잡 해제
select cron.unschedule(jobid) from cron.job where jobname = 'market_expire';

-- (참고) expires_at 컬럼과 expire_market_items() 함수는 그대로 두어도 무해하다(이제 호출되지 않음).
--        추후 '이력 N개 초과 시 오래된 것부터 정리' 같은 기능을 넣을 때 재활용 가능.

-- 확인: 아래가 0행이면 자동삭제 잡이 해제된 것.
-- select * from cron.job where jobname = 'market_expire';
