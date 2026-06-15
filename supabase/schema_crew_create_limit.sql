-- schema_crew_create_limit.sql — 크루(동네 그룹) 1인당 생성 1개 제한
-- 규칙: '참여(crew_group_member)'는 여러 군데 가능, '만들기(crew_group INSERT)'만 1개.
-- INSERT에만 적용 → creator 위임(schema_crew_transfer, UPDATE)은 영향 없음.
-- 기존 크루를 삭제하면 다시 만들 수 있음(1개 '동시 보유' 제한).
-- ⚠️ crew_* 는 BabyLog 전용 테이블. schema_crew.sql 이후 실행.

create or replace function public.crew_group_one_per_creator()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.crew_group where creator = new.creator) then
    raise exception 'crew_create_limit' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists crew_group_one_per_creator_t on public.crew_group;
create trigger crew_group_one_per_creator_t
  before insert on public.crew_group
  for each row execute function public.crew_group_one_per_creator();
