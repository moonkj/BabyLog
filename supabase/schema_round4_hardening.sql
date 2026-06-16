-- schema_round4_hardening.sql — 반복 리뷰 Round 4 보완 (서버 강제 + 신고 남용 방어)
-- ⚠️ 공유 프로젝트(crew_/market_ 접두사). schema_write_forgery_lockdown.sql 이후(또는 함께) 실행.
--    (이 파일은 crew_meetup_join 의 직접 INSERT 정책을 제거하므로, 그 이후 crew_rls 재실행 금지.)

-- ════════════ 1) 모임 정원(capacity) 서버 강제 — R2-2 (CRITICAL) ════════════
-- 문제: crew_meetup_join 직접 INSERT는 정원 초과를 막지 못해, 클라 isFull 게이트를 우회해
--   PostgREST로 무제한 참가 행을 주입할 수 있었다(정원 표시 교란·푸시 비용 증가).
-- 해결: 참가를 SECURITY DEFINER RPC로만 허용하고, 함수 내부에서 advisory lock + 정원 검사.
--   직접 INSERT/UPDATE 정책은 제거(함수는 definer 권한이라 RLS 우회). DELETE(본인 탈퇴)는 유지.
create or replace function public.crew_join_meetup(p_meetup uuid)
returns text language plpgsql security definer set search_path = public as $$
declare me text; cap int; cnt int;
begin
  me := auth.uid()::text;
  if me is null then return 'unauthorized'; end if;               -- 로그인 필수
  -- 동시 참가 레이스 방지: 모임 단위 배타 락(트랜잭션 종료 시 자동 해제)
  perform pg_advisory_xact_lock(hashtext('meetup:' || p_meetup::text));
  select capacity into cap from public.crew_meetup where id = p_meetup and expires_at > now();
  if cap is null then return 'not_found'; end if;                 -- 없거나 만료
  if exists (select 1 from public.crew_meetup_join
              where meetup_id = p_meetup and device_id = me) then
    return 'ok';                                                  -- 이미 참가(멱등)
  end if;
  select count(*) into cnt from public.crew_meetup_join where meetup_id = p_meetup;
  if cnt >= cap then return 'full'; end if;                       -- 정원 마감
  insert into public.crew_meetup_join(meetup_id, device_id) values (p_meetup, me)
    on conflict (meetup_id, device_id) do nothing;
  return 'ok';
end; $$;
grant execute on function public.crew_join_meetup(uuid) to authenticated;

-- 직접 참가 INSERT/UPDATE 봉쇄 — 이제 RPC(crew_join_meetup)로만 참가. (DELETE=본인 탈퇴는 유지)
alter table public.crew_meetup_join enable row level security;
drop policy if exists crew_meetup_join_ins on public.crew_meetup_join;
drop policy if exists crew_meetup_join_upd on public.crew_meetup_join;
-- (crew_meetup_join_del / crew_meetup_join_read 는 write_forgery_lockdown / crew_rls 정의 유지)

-- ════════════ 2) 신고(report) 남용 방어 — R2-6 ════════════
-- (a) market_report — 익명 reporter 위조 차단. 마켓은 로그인 필수이므로 to authenticated + 본인 고정.
alter table public.market_report enable row level security;
drop policy if exists market_report_ins on public.market_report;
create policy market_report_ins on public.market_report for insert to authenticated
  with check ( reporter = auth.uid()::text );

-- (b) 신고 본문·증거 크기 상한 — 거대 페이로드로 테이블 비대화(저장 DoS) 방지.
--     멱등하게: 이미 있으면 건너뜀.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'market_report_note_len') then
    alter table public.market_report add constraint market_report_note_len
      check (note is null or char_length(note) <= 2000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'market_report_transcript_sz') then
    alter table public.market_report add constraint market_report_transcript_sz
      check (pg_column_size(transcript) <= 131072);   -- ~128KB
  end if;
end $$;

-- bl_report(크루/콘텐츠 신고)도 동일 크기 상한(테이블이 있을 때만).
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='bl_report') then
    if exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='bl_report' and column_name='note')
       and not exists (select 1 from pg_constraint where conname = 'bl_report_note_len') then
      alter table public.bl_report add constraint bl_report_note_len
        check (note is null or char_length(note) <= 2000);
    end if;
    if exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='bl_report' and column_name='transcript')
       and not exists (select 1 from pg_constraint where conname = 'bl_report_transcript_sz') then
      alter table public.bl_report add constraint bl_report_transcript_sz
        check (pg_column_size(transcript) <= 131072);
    end if;
  end if;
end $$;

-- ════════════ 검증 ════════════
-- (1) 참가 RPC 존재 + 직접 INSERT 정책 없음:
--   select proname from pg_proc where proname='crew_join_meetup';
--   select cmd, count(*) from pg_policies where tablename='crew_meetup_join' group by cmd;  -- INSERT 0행
-- (2) market_report INSERT 가 authenticated 전용 + reporter=auth.uid:
--   select roles, with_check from pg_policies where tablename='market_report' and cmd='INSERT';
-- (3) 크기 제약:
--   select conname from pg_constraint where conname like '%report%len' or conname like '%report%sz';
