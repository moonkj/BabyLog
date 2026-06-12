-- BabyLog · 서버 보안 강화 (출시 전 권장) — KNOWN_ISSUES A3
-- using(true)로 열려 있던 Storage 쓰기/삭제를 소유 폴더 기준으로 잠근다.
-- 앱: 사진 경로 첫 폴더 = ownerID(로그인 auth.uid / 아니면 기기ID), 동일 값을 x-device-id 헤더로 전송
--     (MarketBackend.uploadPhoto/deletePhoto). 멱등 — SQL Editor에서 1회 실행.

-- ───────── Storage: market-photos 소유 폴더만 업로드/삭제 ─────────
-- 읽기는 공개(공개 버킷·상품 사진). 쓰기/삭제는 자기 폴더(<ownerID>/...)만 → 남의 사진 삭제·도배 차단.
drop policy if exists market_photos_read on storage.objects;
drop policy if exists market_photos_ins  on storage.objects;
drop policy if exists market_photos_del  on storage.objects;
create policy market_photos_read on storage.objects for select to anon, authenticated
  using ( bucket_id = 'market-photos' );
create policy market_photos_ins on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'market-photos'
    and (storage.foldername(name))[1] = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  );
create policy market_photos_del on storage.objects for delete to anon, authenticated
  using (
    bucket_id = 'market-photos'
    and (storage.foldername(name))[1] = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  );

-- ───────── 미적용(주의) ─────────
-- crew_push_token / crew_waitlist 의 소유자 RLS는 보류:
--   이 테이블들은 '기기 단위'라 본문 device_id=기기ID인데, 공용 request() 헤더 x-device-id=ownerID(로그인 시 auth.uid)
--   라서 coalesce(auth.uid, header) 기준으로 잠그면 로그인 사용자의 정상 upsert가 막힌다.
--   올바른 적용: 해당 호출만 device_id 전용 헤더를 보내도록 클라 수정 후 device_id=헤더 기준으로 잠글 것.
--   (위험: 타인 푸시토큰 삭제(알림 DoS)/가짜 대기자 — 중간 우선순위. KNOWN_ISSUES A4.)
