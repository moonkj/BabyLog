-- BabyLog · 소유자 기반 RLS (크루 + 마켓) — 보안 잠금
-- 현재 using(true)(누구나 수정/삭제) → "본인 글만 수정/삭제"로 전환.
--
-- 소유자 식별(전환기 하이브리드):
--   • 로그인: auth.uid()  ← 위조 불가(강력)
--   • 익명:   x-device-id 헤더  ← 전환기(스푸핑 가능하나 무차별 삭제는 차단). 로그인 의무화 시 헤더 제거.
-- 앱은 owner 컬럼/헤더에 ownerID(로그인 시 auth.uid, 아니면 기기ID)를 보낸다(CrewBackend.ownerID()).
--
-- ⚠️ 적용 순서: schema_crew.sql / schema_market.sql / schema_auth.sql 이후 실행.
-- ⚠️ 업서트(on_conflict) 테이블은 UPDATE 정책에 헤더를 쓰면 42501 → 헤더는 DELETE에만.
-- 읽기는 모두 공개(동네 커뮤니티). market_report(신고)는 INSERT 전용 유지(여기서 안 건드림).

do $$
declare
  hdr  constant text := '(current_setting(''request.headers'', true)::json ->> ''x-device-id'')';
  r    record;
begin
  -- ───────── 소유자 컬럼 테이블(업서트 아님): 본인만 update/delete ─────────
  for r in select * from (values
      ('crew_post','author'),
      ('crew_post_reply','author'),
      ('crew_meetup','host'),
      ('crew_group','creator'),
      ('crew_meetup_message','device_id'),
      ('market_item','seller'),
      ('market_chat_message','device_id')
    ) as x(tbl, owner)
  loop
    execute format('alter table public.%I enable row level security;', r.tbl);
    execute format('drop policy if exists %I_all  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_read on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_ins  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_upd  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_del  on public.%I;', r.tbl, r.tbl);
    execute format('create policy %I_read on public.%I for select to anon, authenticated using (true);', r.tbl, r.tbl);
    -- insert: 로그인은 owner=본인 강제, 익명은 자유(신원 없음)
    execute format('create policy %I_ins on public.%I for insert to anon, authenticated with check (%I = coalesce(auth.uid()::text, %I));',
                   r.tbl, r.tbl, r.owner, r.owner);
    -- update/delete: 본인(로그인 uid 또는 익명 헤더)만
    execute format('create policy %I_upd on public.%I for update to anon, authenticated using (%I = coalesce(auth.uid()::text, %s)) with check (%I = coalesce(auth.uid()::text, %s));',
                   r.tbl, r.tbl, r.owner, hdr, r.owner, hdr);
    execute format('create policy %I_del on public.%I for delete to anon, authenticated using (%I = coalesce(auth.uid()::text, %s));',
                   r.tbl, r.tbl, r.owner, hdr);
  end loop;

  -- ───────── 업서트 테이블(device_id): insert/update 무차별 허용(on_conflict), delete만 본인 ─────────
  for r in select * from (values
      ('crew_post_like'),
      ('crew_meetup_join'),
      ('crew_group_member')
    ) as x(tbl)
  loop
    execute format('alter table public.%I enable row level security;', r.tbl);
    execute format('drop policy if exists %I_all  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_read on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_ins  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_upd  on public.%I;', r.tbl, r.tbl);
    execute format('drop policy if exists %I_del  on public.%I;', r.tbl, r.tbl);
    execute format('create policy %I_read on public.%I for select to anon, authenticated using (true);', r.tbl, r.tbl);
    -- insert/update: 헤더 미사용(ON CONFLICT DO UPDATE 42501 회피). 로그인은 본인 강제.
    execute format('create policy %I_ins on public.%I for insert to anon, authenticated with check (device_id = coalesce(auth.uid()::text, device_id));', r.tbl, r.tbl);
    execute format('create policy %I_upd on public.%I for update to anon, authenticated using (device_id = coalesce(auth.uid()::text, device_id)) with check (device_id = coalesce(auth.uid()::text, device_id));', r.tbl, r.tbl);
    -- delete: 본인(로그인 uid 또는 익명 헤더)만 — 남의 좋아요/참가 취소 차단
    execute format('create policy %I_del on public.%I for delete to anon, authenticated using (device_id = coalesce(auth.uid()::text, %s));', r.tbl, r.tbl, hdr);
  end loop;
end $$;

-- 참고: 로그인 의무화(완전 잠금) 단계에선 위 coalesce 폴백과 헤더를 제거하고
--       owner = auth.uid()::text 로 고정한다(docs/AUTH_SETUP.md §5.3).
