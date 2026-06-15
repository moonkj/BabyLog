-- BabyLog · bl_owner_id() 재적용 — 가족 보관함 생성 42501(RLS) 수정
-- 증상: 로그인 상태인데 "new row violates row-level security policy for table bl_family"(42501).
-- 원인: bl_* 정책은 bl_owner_id() 함수를 쓰는데, 배포된 함수가 구버전(auth.uid()만)이라
--       서버에서 auth.uid()가 안 잡히는 순간 x-device-id 헤더 폴백이 동작하지 않아 INSERT가 막힘.
--       (크루/마켓은 같은 coalesce 패턴을 정책에 '인라인'으로 둬서 정상 — 그래서 가족만 실패.)
-- 해결: 함수에 헤더 폴백을 포함한 최신 정의로 갱신(멱등). 앱은 모든 쓰기에 x-device-id=ownerID를 보냄.

-- search_path 고정 — 모든 bl_* RLS 정책이 의존하는 핵심 함수라 공유 프로젝트에서 객체 셰도잉
--   권한상승 벡터를 차단(다른 definer 함수와 동일 정책).
create or replace function public.bl_owner_id()
returns text language sql stable
set search_path = public as $$
  select coalesce(
    auth.uid()::text,
    nullif(current_setting('request.headers', true)::json ->> 'x-device-id', '')
  );
$$;
