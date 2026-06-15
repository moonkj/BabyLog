-- schema_security_medium.sql — 리뷰 MEDIUM 보안 보강
-- crew_waitlist INSERT 잠금: '아무나 자기 행' → '본인 식별자와 일치하는 행만'.
--   임의 device_id 30건으로 크루 강제오픈·동네 푸시 스팸을 막는다(unique(hood,device_id)와 함께).
--   로그인 시 auth.uid, 비로그인 시 x-device-id 헤더(로그인 의무화 시 헤더 제거 예정).
-- ⚠️ schema.sql 이후 실행. (notify-crew-chat 발신자 검증은 Edge 배포로 별도 반영)

drop policy if exists crew_waitlist_insert on public.crew_waitlist;
create policy crew_waitlist_insert on public.crew_waitlist
    for insert to anon, authenticated
    with check (
      device_id = coalesce(
        auth.uid()::text,
        (current_setting('request.headers', true)::json ->> 'x-device-id')
      )
    );
