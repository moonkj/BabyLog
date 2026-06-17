-- schema_family_moderation.sql
-- 가족 피드 보안·모더레이션 보강 (출시 전).
--   1) author_name 서버 강제 — 좋아요/댓글의 표시이름을 클라이언트 입력이 아니라
--      가족 멤버(display_name)에서 서버가 채움(작성자 사칭 차단).
--   2) 주인 댓글 삭제 — 가족 보관함 주인(부모)이 부적절한 댓글을 삭제할 수 있게(App Store 1.2 모더레이션).
-- 실행: Supabase SQL Editor에서 1회(멱등). 앱 빌드 불필요.

-- ─────────────────────────────────────────────────────────────
-- 1) author_name 서버 강제 (좋아요·댓글)
--    클라이언트가 author_name을 보내도, 호출자(bl_owner_id())의 가족 멤버 표시이름으로 덮어쓴다.
--    멤버를 못 찾으면(엣지) 보낸 값을 유지(삽입은 막지 않음 — 가용성 우선).
-- ─────────────────────────────────────────────────────────────
create or replace function public.bl_enforce_author_name()
returns trigger language plpgsql security definer
set search_path = public as $$
declare nm text;
begin
  select display_name into nm
  from public.bl_family_member
  where family_id = new.family_id and uid = public.bl_owner_id()
  limit 1;
  if nm is not null and length(btrim(nm)) > 0 then
    new.author_name := left(nm, 40);   -- 서버가 멤버 표시이름으로 강제(사칭 방지)
  end if;
  return new;
end $$;

drop trigger if exists bl_reaction_author_name on public.bl_reaction;
create trigger bl_reaction_author_name before insert on public.bl_reaction
  for each row execute function public.bl_enforce_author_name();

drop trigger if exists bl_comment_author_name on public.bl_comment;
create trigger bl_comment_author_name before insert on public.bl_comment
  for each row execute function public.bl_enforce_author_name();

-- ─────────────────────────────────────────────────────────────
-- 2) 주인 댓글 삭제 정책 (기존 '작성자 본인 삭제'에 추가 — RLS는 OR로 합쳐짐)
--    가족 보관함 주인(owner_uid)은 자기 가족의 어떤 댓글이든 삭제 가능.
-- ─────────────────────────────────────────────────────────────
drop policy if exists bl_comment_delete_owner on public.bl_comment;
create policy bl_comment_delete_owner on public.bl_comment for delete
  using (family_id in (select id from public.bl_family where owner_uid = public.bl_owner_id()));

-- ─────────────────────────────────────────────────────────────
-- (보류) 아래 두 건은 효과는 크지만 라이브 동작을 깨뜨릴 수 있어 '테스트 후' 적용 권장.
--   A) 가족 bl_* 쓰기에서 x-device-id 헤더 폴백 제거 → auth.uid() 고정.
--      위험: 이 프로젝트는 auth.uid()가 null로 떨어진 이력이 있어(앱 주석 참조) 적용 시
--            가족 쓰기 전체가 막힐 수 있음. 적용 전, 로그인 사용자/웹 익명합류 양쪽에서
--            bl_reaction INSERT가 정상인지 스테이징 검증 필수.
--      예: create policy bl_reaction_write on public.bl_reaction for insert to authenticated
--            with check (uid = auth.uid()::text and bl_is_family_member(family_id));
--   B) crew_push_token 쓰기 소유 검증.
--      위험: 푸시 토큰은 '로그인 전' 기기ID로도 등록됨(device_id = 기기 UUID). auth.uid() 강제 시
--            로그인 전 푸시 등록이 막힘. 안전한 대안 설계(예: device_id == bl_owner_id() with check,
--            단 ON CONFLICT 업서트 호환 확인) 후 적용.
-- ─────────────────────────────────────────────────────────────

-- 검증(선택): 정책·트리거 확인
-- select tgname from pg_trigger where tgname in ('bl_reaction_author_name','bl_comment_author_name');
-- select policyname from pg_policies where tablename='bl_comment';
