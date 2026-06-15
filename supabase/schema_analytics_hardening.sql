-- schema_analytics_hardening.sql — bl_admin_stats 노출 차단 + 검증 핑 정리
-- Postgres 함수는 기본 PUBLIC execute라 anon도 통계 함수를 직접 호출할 수 있었음 → 회수.
-- 집계는 service_role(admin-action Edge)만, 운영자 화이트리스트는 Edge에서 강제.

-- Supabase는 public 스키마 함수에 anon/authenticated 명시 grant를 걸어둬 'from public'만으론 안 빠짐 → 명시 회수.
revoke execute on function public.bl_admin_stats(int, text[]) from public, anon, authenticated;
grant  execute on function public.bl_admin_stats(int, text[]) to service_role;

-- 검증 과정에서 생성된 테스트 핑 제거(실집계 오염 방지)
delete from public.bl_active_ping where device_id like 'BLTEST-%';
