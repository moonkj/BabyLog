-- schema_family_member_unique.sql — 가족 멤버 중복행 정리 + 유일 제약 (#7)
-- 레이스로 같은 (family_id, uid) 멤버행이 2개 생기면 notify-family-join의 maybeSingle()이 throw해
-- 주인이 합류 푸시를 통째로 놓쳤다. 중복 정리 후 유일 인덱스로 재발 방지.

-- 1) 중복 정리 — (family_id, uid)별로 approved 우선 → 이른 joined_at → 작은 id 1행만 남기고 삭제.
delete from public.bl_family_member
 where id in (
   select id from (
     select id, row_number() over (
       partition by family_id, uid
       order by approved desc nulls last, joined_at asc nulls last, id asc
     ) as rn
     from public.bl_family_member
     where uid is not null
   ) t where t.rn > 1
 );

-- 2) 유일 제약(부분 인덱스 — uid 있는 행만; 초대코드만 있는 대기행은 uid null이라 제외).
create unique index if not exists bl_family_member_family_uid_uidx
  on public.bl_family_member(family_id, uid) where uid is not null;
