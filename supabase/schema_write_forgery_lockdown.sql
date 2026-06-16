-- schema_write_forgery_lockdown.sql — Round 3 백엔드 보안: 쓰기 위조 잠금 (R2-1/3/7)
-- ════════════════════════════════════════════════════════════════════════════
-- 목적: crew/market 의 쓰기(INSERT/UPDATE/DELETE) 위조를 닫는다.
--   배경: 로그인 의무화(commit 4aec722) 후에도 RLS가
--          `coalesce(auth.uid()::text, owner컬럼)` 또는 `coalesce(auth.uid()::text, x-device-id헤더)`
--          폴백이라, anon 키 + 위조 페이로드(또는 위조 헤더)로 타인 사칭 작성·
--          캡/정원/상태 우회·남의 글 수정·삭제가 가능했다.
--   해결: crew/market 쓰기 정책을 `to authenticated` + `owner = auth.uid()::text`(USING·WITH CHECK 모두)로
--          고정한다. owner 컬럼/헤더 폴백을 전부 제거 → 위조 페이로드·헤더로는 본인 행을 만들 수 없다.
--
-- ⚠️ 적용 순서(불변식): 이 파일은 "가장 마지막"에 실행한다.
--    구체적으로 schema_chat_push_hardening.sql(채팅 비공개·증거보존·푸시토큰 잠금) 이후,
--    schema_security_blockers.sql / schema_launch_security.sql 이후. (모든 스키마 적용 끝에 1회.)
--    이 파일은 채팅 SELECT(1:1 비공개) 정책과 증거보존(메시지 UPDATE/DELETE 정책 없음)을 깨지 않는다.
--
-- ✅ 정상 사용자 무영향 근거(실제 코드 확인):
--   • crew/market 쓰기는 전부 Apple 로그인 필수(MarketScreen "매물 등록은 로그인이 필요해요",
--     CrewGroupDetail "그룹 가입·채팅은 로그인이 필요해요"). 앱 AuthStore는 Apple id_token 로그인만
--     수행(익명 로그인 없음) → 쓰기 호출엔 항상 비익명 auth.uid()가 실린다.
--   • CrewBackend.request()/MarketBackend 가 모든 쓰기에 `Authorization: Bearer <user JWT>`를 보내고,
--     owner 컬럼/헤더 x-device-id 에 SupabaseConfig.ownerID()(=로그인 시 auth.uid())를 넣는다.
--     즉 본인 행 = auth.uid() 라서 `owner = auth.uid()::text` 고정이 정상 흐름을 막지 않는다.
--   • 가족 웹(익명 세션)은 bl_* 테이블만 쓴다 → crew/market 정책과 무관(여기서 안 건드림).
--
-- ⛔ 의도적으로 제외(깨지면 안 되는 비로그인 정당 경로):
--   • crew_waitlist  : 기기 단위. INSERT 페이로드 device_id = '원시 deviceID'(ownerID 아님,
--                      CrewBackend.joinWaitlist line 72)인데 로그인 시 coalesce는 auth.uid()를 반환 →
--                      `device_id = auth.uid()`로 고정하면 로그인 사용자의 정상 신청이 깨진다(불일치).
--                      → 손대지 않음. (기존 schema.sql / schema_security_medium.sql 정책 유지.)
--   • crew_push_token: 기기 단위 upsert. schema_chat_push_hardening.sql 의 device_id=coalesce(uid,header)
--                      정책이 로그인/비로그인 모두를 정상 처리(헤더=ownerID). → 손대지 않음.
--   • crew_post_like / crew_meetup_join / crew_group_member : on_conflict 업서트 테이블.
--                      INSERT/UPDATE 에 헤더를 쓰면 42501(ON CONFLICT DO UPDATE)이 나므로
--                      schema_crew_rls.sql 가 device_id=coalesce(uid,device_id) 폴백을 쓴다.
--                      로그인 의무화로 device_id=auth.uid() 고정이 가능하나, joinMeetup/joinGroup/like 가
--                      body device_id에 ownerID(=auth.uid())를 넣는지 코드 미확정이라 회귀를 피해
--                      이 파일에서는 INSERT는 건드리지 않고 DELETE만 본인(uid) 고정으로 강화한다.
--                      (헤더 폴백 제거 → 위조 헤더로 남의 좋아요/참가 취소 차단.)

do $$
declare
  r record;
begin
  -- ════════════ A) 소유자 컬럼 콘텐츠 테이블 — INSERT/UPDATE/DELETE 본인(auth.uid) 고정 ════════════
  -- 대상: 글·댓글·모임·그룹·모임채팅 + 마켓 매물. (owner 컬럼 = auth.uid()::text)
  -- to authenticated 로 anon 키 직접쓰기 봉쇄. owner 컬럼/헤더 폴백 전부 제거 → 사칭 위조 불가.
  -- ⚠️ 채팅 테이블(crew_meetup_message)은 INSERT만 고정, UPDATE/DELETE 정책은 만들지 않는다(증거 보존).
  -- market_chat_message / crew_group_message 는 SELECT·INSERT 가 chat_push_hardening 에 1:1/멤버십
  --   검증 포함으로 이미 정의돼 있으므로 여기서 별도 처리(아래 C 블록).
  for r in select * from (values
      ('crew_post','author',       true),   -- (tbl, owner, has_update) — has_update=false 면 UPDATE 정책 미생성(증거보존)
      ('crew_post_reply','author',  true),   -- 본인 댓글 수정 허용(owner=auth.uid라 위조 불가). 기존 upd 동작 유지.
      ('crew_meetup','host',        true),
      ('crew_group','creator',      true),
      ('crew_meetup_message','device_id', false),  -- 채팅: INSERT만, UPDATE/DELETE 없음(증거보존)
      ('market_item','seller',      true)
    ) as x(tbl, owner, has_update)
  loop
    execute format('alter table public.%I enable row level security;', r.tbl);
    -- 기존 정책 전부 제거(폴백·anon 포함). 채팅은 read/upd/del 정책이 애초에 없을 수 있어 if exists.
    execute format('drop policy if exists %I_all  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_read on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_ins  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_upd  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_del  on public.%I;', r.tbl, r.tbl);

    -- SELECT: 동네 커뮤니티는 읽기 공개 유지(anon 포함). 모임 채팅(crew_meetup_message)도
    --   동네 그룹 채팅이라 읽기 공개(using(true))가 라이브 상태 — 위에서 drop 했으므로 반드시 재생성한다.
    --   (재생성 누락 시 모임 채팅이 전원에게 안 보이는 회귀. 1:1 비공개 채팅인 market_chat_message는
    --    이 목록에 없고 C-1에서 별도 처리하므로 여기 전체 재생성이 비공개를 깨지 않는다.)
    execute format('create policy %I_read on public.%I for select to anon, authenticated using (true);', r.tbl, r.tbl);

    -- INSERT: 로그인 사용자만, owner = 본인 auth.uid 강제(위조 차단). 폴백 없음.
    execute format(
      'create policy %I_ins on public.%I for insert to authenticated with check (%I = auth.uid()::text);',
      r.tbl, r.tbl, r.owner);

    -- UPDATE/DELETE: 본인(auth.uid)만. 헤더 폴백 제거 → 위조 헤더로 타인 글 수정·삭제 불가.
    --   채팅(has_update=false 중 meetup_message)은 UPDATE/DELETE 정책을 만들지 않음(증거 보존).
    if r.has_update then
      execute format(
        'create policy %I_upd on public.%I for update to authenticated using (%I = auth.uid()::text) with check (%I = auth.uid()::text);',
        r.tbl, r.tbl, r.owner, r.owner);
    end if;
    if r.tbl <> 'crew_meetup_message' then
      execute format(
        'create policy %I_del on public.%I for delete to authenticated using (%I = auth.uid()::text);',
        r.tbl, r.tbl, r.owner);
    end if;
  end loop;

  -- ════════════ B) 업서트(on_conflict) 멤버십 테이블 — DELETE만 본인(auth.uid) 고정 ════════════
  -- crew_post_like / crew_meetup_join / crew_group_member.
  -- INSERT/UPDATE 는 schema_crew_rls.sql 정의(device_id=coalesce(uid,device_id)) 유지 — ON CONFLICT 42501 회피.
  -- DELETE 만 헤더 폴백을 제거하고 auth.uid 고정 → 위조 헤더로 남의 좋아요/참가/가입 취소 차단(R2-7 일부).
  for r in select * from (values
      ('crew_post_like'),
      ('crew_meetup_join'),
      ('crew_group_member')
    ) as x(tbl)
  loop
    execute format('alter table public.%I enable row level security;', r.tbl);
    execute format('drop policy if exists %I_del on public.%I;', r.tbl, r.tbl);
    execute format(
      'create policy %I_del on public.%I for delete to authenticated using (device_id = auth.uid()::text);',
      r.tbl, r.tbl);
  end loop;
end $$;

-- ════════════ C) 채팅/공개글 INSERT — 멤버십·1:1 검증 + 작성자 본인 강제 ════════════
-- 아래 두 테이블은 SELECT(비공개/공개)·증거보존(UPDATE/DELETE 없음) 정의가
-- schema_chat_push_hardening.sql 에 있다. 그 SELECT 는 그대로 두고, INSERT 만
-- to authenticated + 작성자 본인(auth.uid) + (1:1 라우팅 / 멤버십) 검증으로 교체한다.

-- C-1) market_chat_message — 1:1 거래 채팅: 작성자 본인 + (구매자 본인 OR 그 매물 판매자)
-- (기존과 동일한 라우팅이지만 폴백 제거 + to authenticated 로 고정.)
drop policy if exists market_chat_message_ins on public.market_chat_message;
create policy market_chat_message_ins on public.market_chat_message for insert to authenticated with check (
  device_id = auth.uid()::text
  and (
    buyer = auth.uid()::text
    or exists (
      select 1 from public.market_item mi
      where mi.id = item_id
        and mi.seller = auth.uid()::text
    )
  )
);
-- read/update/delete 는 schema_chat_push_hardening.sql 정의 유지(1:1 비공개 + 증거보존).

-- C-2) crew_group_message — 또래 그룹 채팅: 작성자 본인 + '그 그룹 멤버'만 작성 가능.
-- (기존 chat_push_hardening 의 INSERT 는 작성자 본인만 검증하고 멤버십은 검증하지 않았다 →
--  비멤버가 임의 group_id로 채팅 주입 가능. exists 서브쿼리로 멤버십을 추가한다.)
-- ✅ 그룹은 '가입해야 채팅 입장'(CrewGroupDetail: 채팅 버튼 .disabled(!isJoined)) — 멤버십 강제가 설계와 일치.
-- ⚠️ 경합 주의: 가입(setGroupMembership)이 별도 Task 라 가입 직후 즉시 첫 메시지를 보내면
--    crew_group_member 행 커밋 전이라 42501 가능. 정상 흐름(가입→채팅 열기→입력)은 행이 선커밋되어 안전.
--    필요 시 클라가 join 응답 확인 후 입력 활성화하도록 보장(현재는 가입/채팅이 분리된 사용자 동작이라 사실상 OK).
drop policy if exists crew_group_message_ins on public.crew_group_message;
create policy crew_group_message_ins on public.crew_group_message for insert to authenticated with check (
  device_id = auth.uid()::text
  and exists (
    select 1 from public.crew_group_member gm
    where gm.group_id = crew_group_message.group_id
      and gm.device_id = auth.uid()::text
  )
);
-- read/update/delete 는 schema_chat_push_hardening.sql 정의 유지(읽기 공개 + 증거보존).

-- C-3) crew_meetup_message — 모임 채팅: 작성자 본인(auth.uid)만. 멤버십 검증은 '의도적으로 미적용'.
-- ⚠️ 앱 설계상 "정원 마감(isFull)이면 자동 참가하지 않고 채팅만 연다"(CrewMeetupDetail.swift L328-329:
--    참석 희망자·이웃 코디네이션 목적). 즉 정원 찬 모임의 채팅 참여자는 crew_meetup_join 행이 없을 수
--    있다 → 멤버십 exists 를 강제하면 정상 사용자가 막힌다. 또한 자동참가가 별도 Task 라 첫 메시지가
--    join 커밋 전에 갈 수 있다(경합). 따라서 작성자 본인(device_id=auth.uid)만 강제하고 멤버십은 검증하지 않는다.
--    (A 블록에서 만든 device_id=auth.uid INSERT 와 동일 — 명시성을 위해 여기서 재선언.)
drop policy if exists crew_meetup_message_ins on public.crew_meetup_message;
create policy crew_meetup_message_ins on public.crew_meetup_message for insert to authenticated with check (
  device_id = auth.uid()::text
);
-- read 정책은 만들지 않음(기존 정의 보존). update/delete 정책 없음 = 증거 보존.

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 쿼리(적용 후 실행해 확인) — 모든 crew/market 쓰기가 auth.uid 고정인지, 폴백·헤더가 없는지.
-- ════════════════════════════════════════════════════════════════════════════
-- (a) crew/market 쓰기 정책 전수 — roles 에 anon 이 없어야(쓰기는 authenticated 전용),
--     qual/with_check 에 'request.headers' / 'coalesce' 가 없어야(폴백 제거) 한다:
--   select tablename, polname, cmd, roles, qual, with_check
--     from pg_policies
--    where tablename in ('crew_post','crew_post_reply','crew_meetup','crew_group',
--                        'crew_meetup_message','crew_group_message','market_item','market_chat_message',
--                        'crew_post_like','crew_meetup_join','crew_group_member')
--      and cmd in ('INSERT','UPDATE','DELETE')
--    order by tablename, cmd;
--   ⮕ 모든 INSERT/UPDATE/DELETE 행의 roles 가 {authenticated} 이고,
--      with_check/qual 에 'auth.uid()' 가 들어가며 'headers'/'coalesce' 가 없어야 OK.
--
-- (b) 1:1 채팅 비공개 유지 — market_chat_message SELECT 가 using(true)가 아니어야:
--   select polname, cmd, qual from pg_policies where tablename='market_chat_message';
--
-- (c) 증거 보존 — 채팅 3종에 UPDATE/DELETE 정책이 없어야(0행):
--   select tablename, cmd, count(*) from pg_policies
--    where tablename in ('market_chat_message','crew_group_message','crew_meetup_message')
--      and cmd in ('UPDATE','DELETE') group by 1,2;   -- ⮕ 0행
--
-- (d) 비로그인 정당 경로 무손상 — waitlist/push_token 정책은 그대로(폴백/헤더 유지):
--   select tablename, polname, cmd, qual, with_check from pg_policies
--    where tablename in ('crew_waitlist','crew_push_token') order by 1,3;
--
-- 회귀 위험 요약:
--   • 로그인 사용자(Apple) 정상 쓰기: 영향 없음(owner=auth.uid 항상 일치).
--   • 비로그인 사용자의 crew/market 쓰기: 앱이 이미 로그인 게이트로 차단 → 영향 없음.
--   • crew_meetup_message(C-3): 멤버십 검증 '미적용' — 정원 마감 모임의 정당한 채팅 참여자를
--     막지 않기 위해 작성자 본인만 강제. (정원 우회 위험은 crew_meetup_join INSERT 정책/캡으로 별도 관리.)
--   • crew_group_message(C-2): 멤버십 검증 '적용' — 가입 후 채팅 설계와 일치. 가입 직후 즉시 전송 시
--     드문 경합으로 첫 메시지 42501 가능(클라가 가입/채팅을 분리 동작으로 처리해 사실상 안전).
--   • crew_post_reply: 기존 UPDATE 정책 제거(댓글 수정 불가) — 앱이 댓글 수정 기능을 쓰지 않으면 무영향.
--     (만약 댓글 수정 UI가 있다면 A 블록 crew_post_reply 행의 has_update 를 true 로 바꿀 것.)
