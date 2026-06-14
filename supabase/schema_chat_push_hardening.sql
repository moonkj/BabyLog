-- BabyLog · 보안 하드닝 (채팅 비공개·증거 보존 + 그룹채팅 RLS + 푸시토큰 잠금)
-- ⚠️ 반드시 schema_crew.sql / schema_market.sql / schema_crew_rls.sql 를 모두 적용한 "맨 마지막"에 실행.
--    (schema_crew_rls.sql의 소유자 루프가 일부 채팅 정책을 느슨하게 덮어쓰므로 이 파일로 바로잡는다.)
-- 운영자(service_role)는 모든 RLS를 우회하므로 신고 조회·정리는 그대로 동작한다.

-- ───────── 1) crew_group_message — 공개(FOR ALL true) 정책 잠금 ─────────
-- 기존: 누구나 모든 그룹 채팅을 읽기/수정/삭제 가능(schema_crew_rls.sql 누락분).
-- 변경: 읽기 공개(동네 그룹), 작성은 본인만, 수정·삭제 불가(증거 보존).
alter table public.crew_group_message enable row level security;
drop policy if exists crew_group_message_all  on public.crew_group_message;
drop policy if exists crew_group_message_read on public.crew_group_message;
drop policy if exists crew_group_message_ins  on public.crew_group_message;
drop policy if exists crew_group_message_upd  on public.crew_group_message;
drop policy if exists crew_group_message_del  on public.crew_group_message;
create policy crew_group_message_read on public.crew_group_message for select to anon, authenticated using (true);
create policy crew_group_message_ins  on public.crew_group_message for insert to anon, authenticated
  with check (device_id = coalesce(auth.uid()::text, device_id));
-- update/delete 정책 없음(의도적): 채팅 증거 보존. 운영자(service_role)만 정리.

-- ───────── 2) crew_meetup_message — 채팅 증거 보존 ─────────
-- 소유자 루프가 만든 수정/삭제 정책 제거 → 신고된 사용자가 대화를 지우지 못하게.
drop policy if exists crew_meetup_message_upd on public.crew_meetup_message;
drop policy if exists crew_meetup_message_del on public.crew_meetup_message;

-- ───────── 3) market_chat_message — 1:1 비공개 복구 + 증거 보존 ─────────
-- ⚠️ 소유자 루프가 read를 using(true)(전체 공개)로 덮어써 1:1 거래 채팅이 "모두에게" 노출됐다.
--    원래 의도(해당 구매자 본인 OR 그 매물 판매자만 열람)로 되돌리고, 작성도 참여자만, 수정/삭제 불가.
drop policy if exists market_chat_message_read on public.market_chat_message;
drop policy if exists market_chat_message_ins  on public.market_chat_message;
drop policy if exists market_chat_message_upd  on public.market_chat_message;
drop policy if exists market_chat_message_del  on public.market_chat_message;
create policy market_chat_message_read on public.market_chat_message for select to anon, authenticated using (
  buyer = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  or exists (
    select 1 from public.market_item mi
    where mi.id = item_id
      and mi.seller = coalesce(auth.uid()::text, (current_setting('request.headers', true)::json ->> 'x-device-id'))
  )
);
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
-- update/delete 정책 없음(의도적): 증거 보존.

-- ───────── 4) crew_push_token — 토큰 하베스트/타인 토큰 조작 차단 ─────────
-- 기존 FOR ALL(true)는 SELECT까지 포함 → 전체 기기 토큰 조회 + 타인 행 삭제/덮어쓰기 가능.
-- 변경: 본인(uid/헤더)만 insert/update, SELECT·DELETE 정책 없음 → 서버(service_role, notify-*)만 조회·정리.
-- request()가 모든 쓰기에 x-device-id 헤더를 보내므로 본인 행 upsert(on_conflict)는 그대로 통과.
alter table public.crew_push_token enable row level security;
drop policy if exists crew_push_all    on public.crew_push_token;
drop policy if exists crew_push_upsert on public.crew_push_token;
drop policy if exists crew_push_update on public.crew_push_token;
drop policy if exists crew_push_ins    on public.crew_push_token;
drop policy if exists crew_push_upd    on public.crew_push_token;
create policy crew_push_ins on public.crew_push_token for insert to anon, authenticated
  with check (device_id = coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id', '')));
create policy crew_push_upd on public.crew_push_token for update to anon, authenticated
  using (device_id = coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id', '')))
  with check (device_id = coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id', '')));
