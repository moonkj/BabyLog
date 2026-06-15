-- schema_family_post_owner_delete.sql
-- BabyLog · 가족 피드 — 작성자뿐 아니라 '가족 보관함 주인(부모)'도 게시물 삭제 가능.
-- 배경: 재설치/로그인으로 작성자 uid가 바뀌면 본인이 올린 사진도 삭제 버튼이 안 보임.
--       가족을 만든 소유자(부모)는 보관함 정리를 위해 어떤 게시물이든 지울 수 있어야 한다.
-- 미디어·하트·댓글은 FK on delete cascade로 함께 삭제됨. (R2 원본은 media-delete Edge 또는 추후 정리)
-- 멱등: drop policy if exists → create.

drop policy if exists bl_post_delete on public.bl_feed_post;
create policy bl_post_delete on public.bl_feed_post for delete using (
  author_uid = public.bl_owner_id()
  or exists (
    select 1 from public.bl_family f
    where f.id = family_id and f.owner_uid = public.bl_owner_id()
  )
);

-- ────────────────────────────────────────────────────────────────────
-- (선택) 남아있는 옛 테스트 사진 일괄 정리 — 필요할 때만 주석 해제 후 실행.
-- 내가 소유한 가족의 모든 게시물 삭제(미디어·하트·댓글 cascade). uid 식별이 안 되는
-- SQL 편집기(service_role)에서는 아래처럼 '특정 family_id' 또는 전체로 지운다.
--
-- 1) 특정 가족만:   delete from public.bl_feed_post where family_id = '<여기에 family_id>';
-- 2) 전체(테스트):  delete from public.bl_feed_post;     -- ⚠️ bl_ 가족 피드 글 전부 삭제(테스트 전용)
-- ────────────────────────────────────────────────────────────────────
