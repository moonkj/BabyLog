-- schema_round2_hardening.sql — 반복 리뷰 Round 2 보완
-- ⚠️ 공유 프로젝트(market_ 접두사). schema_market_confirm_searchpath.sql 이후 실행.

-- 거래 인증 셀프 위조 차단 — 판매자가 sold_to를 본인(보조계정)으로 지정해 buyer_confirmed를
-- 셀프로 켜서 '인증 거래수'를 부풀리는 것을 막는다(신뢰·안전). 구매자=판매자면 거부.
create or replace function public.market_confirm_trade(p_item uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare me text;
begin
  me := coalesce(auth.uid()::text, nullif(current_setting('request.headers', true)::json ->> 'x-device-id',''));
  update public.market_item
     set buyer_confirmed = true
   where id = p_item and sold_to = me and status = '판매완료'
     and seller <> me;                       -- 셀프 거래(판매자=구매자) 인증 차단
  return found;
end; $$;
grant execute on function public.market_confirm_trade(uuid) to anon, authenticated;
