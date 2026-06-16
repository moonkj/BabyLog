-- schema_launch_security.sql — 출시 전 보안 마감 (마지막에 실행)
-- ⚠️ 공유 프로젝트(bl_/crew_/market_ 접두사). 모든 다른 스키마 적용 '이후 맨 마지막'에 실행.

-- ① 결제 위조 백도어 영구 제거 — 누구나 자기 is_pro=true로 만들 수 있던 함수.
--    (소스에서도 삭제됨. 운영 DB에서 확실히 없애기 위해 멱등 drop.)
drop function if exists public.bl_dev_set_pro(boolean);

-- ② 가족 초대 '비밀번호 우회' 오버로드 제거 — 비번 없이 합류 신청되던 2-인자 버전.
--    비번 검증이 있는 3-인자 bl_claim_invite(code,name,pass)만 남긴다.
drop function if exists public.bl_claim_invite(text, text);

-- ── 적용 후 검증(아래 SELECT들을 실행해 결과를 확인) ──────────────────────
-- (a) 백도어 함수 부재 — 0행이어야 함:
--   select proname, pg_get_function_identity_arguments(oid) args
--     from pg_proc where proname in ('bl_dev_set_pro') ;
--
-- (b) claim_invite 2-인자 부재 — (text,name) 오버로드가 없어야 함(3-인자만):
--   select proname, pg_get_function_identity_arguments(oid) args
--     from pg_proc where proname='bl_claim_invite' order by 2;
--
-- (c) 푸시 토큰 전체노출 정책 부재 — crew_push_token에 SELECT/DELETE 정책이 없어야 함:
--   select polname, cmd, qual from pg_policies where tablename='crew_push_token';
--
-- (d) 마켓 1:1 채팅 비공개 — market_chat_message SELECT가 using(true)가 아니어야 함:
--   select polname, cmd, qual from pg_policies where tablename='market_chat_message';
--
-- (e) 결제 위조 차단 확인 — bl_profile.is_pro는 service_role(verify-subscription)만 써야 함:
--   select polname, cmd, roles, with_check from pg_policies where tablename='bl_profile';
