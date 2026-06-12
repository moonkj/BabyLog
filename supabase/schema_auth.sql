-- BabyLog · 인증(익명→Apple 로그인) 마이그레이션
-- schema_crew.sql 적용 후 실행. Apple 로그인 활성화 전에 미리 둬도 무해(호출 전엔 무영향).
-- 자세한 배경: docs/AUTH_SETUP.md

-- ───────────────────────────────────────────────
-- claim_device: 첫 로그인 시 익명 기기 UUID로 만든 콘텐츠를 내 auth.uid()로 귀속
--   security definer 라 RLS 우회 일괄 UPDATE. 함수 안에서 auth.uid()로만 귀속하므로 안전.
--   auth.uid() 가 null(비로그인)이면 아무것도 하지 않음(소유자 NULL화 방지).
-- ───────────────────────────────────────────────
create or replace function public.claim_device(p_device text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or p_device is null or p_device = '' then
    return;
  end if;

  -- 글/모임/그룹: owner = author/host/creator
  update public.crew_post           set author    = auth.uid()::text where author    = p_device;
  update public.crew_post_reply     set author    = auth.uid()::text where author    = p_device;
  update public.crew_meetup         set host      = auth.uid()::text where host      = p_device;
  update public.crew_group          set creator   = auth.uid()::text where creator   = p_device;

  -- 좋아요/참가/멤버십/메시지: owner = device_id (PK 충돌 시 해당 행은 건너뜀)
  begin update public.crew_post_like      set device_id = auth.uid()::text where device_id = p_device; exception when unique_violation then null; end;
  begin update public.crew_meetup_join    set device_id = auth.uid()::text where device_id = p_device; exception when unique_violation then null; end;
  begin update public.crew_group_member   set device_id = auth.uid()::text where device_id = p_device; exception when unique_violation then null; end;
  update public.crew_meetup_message set device_id = auth.uid()::text where device_id = p_device;
end $$;

grant execute on function public.claim_device(text) to authenticated;

-- ───────────────────────────────────────────────
-- 소유자 기반 RLS는 claim_device로 기존 데이터 정리 후 적용(supabase/schema_crew_rls.sql).
-- 순서가 중요: RLS 먼저 잠그면 옛 익명 행을 본인이 못 고침. docs/AUTH_SETUP.md §7 참고.
-- ───────────────────────────────────────────────
