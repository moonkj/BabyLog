-- schema_reaction_author.sql
-- 가족 피드 '좋아요 누른 사람' 이름 표시 — bl_reaction에 author_name 추가(댓글 bl_comment와 동일 패턴).
--
-- 배경: 좋아요는 uid만 저장해, 웹(조부모)·앱 어디서도 '누가' 눌렀는지 보이지 않았다.
-- 댓글(bl_comment.author_name)과 동일하게 표시이름을 함께 저장한다.
--
-- 호환: 기존 좋아요 행은 기본값 '가족'으로 채워지고, 새 좋아요부터 실제 표시이름이 저장된다.
--       (앱은 가족 멤버 목록 uid→이름 매핑을 우선 사용하므로 기존 행도 앱에선 실제 이름이 보인다.
--        웹은 멤버 목록 권한이 없어 author_name을 그대로 쓴다 — 기존 행은 '가족', 새 행은 실제 이름.)
--
-- RLS 영향 없음: insert 정책은 uid = bl_owner_id() 검사이며 author_name은 단순 데이터 컬럼.
--
-- 실행: Supabase SQL Editor에서 1회 실행(idempotent).

alter table public.bl_reaction
  add column if not exists author_name text not null default '가족';
