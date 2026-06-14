-- BabyLog · market_confirm_trade 하드닝 — security definer 함수에 search_path 고정
-- definer 함수는 호출자의 search_path를 따르면 동명 객체로 가로채기(privilege escalation) 위험이 있어
-- search_path를 public으로 고정한다(프로젝트의 다른 definer 함수와 동일 관례). 동작 변화 없음(멱등).

create or replace function public.market_confirm_trade(p_item uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare me text;
begin
  me := coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id',''));
  update public.market_item
     set buyer_confirmed = true
   where id = p_item and sold_to = me and status = '판매완료';
  return found;
end; $$;
grant execute on function public.market_confirm_trade(uuid) to anon, authenticated;
