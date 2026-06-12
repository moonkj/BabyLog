# 알려진 미해결 이슈 (2026-06-13 전체 재리뷰 기준)

3차에 걸친 병렬 코드 재리뷰에서 대부분의 P0/P1과 다수 P2를 수정·배포했다(커밋 fb2b7bf·eef9adc·18bea28·b527b13). 아래는 **아직 안 고친 항목** — 서버 배포가 필요하거나(현재 access token 폐기로 에이전트가 못 올림), 제품 결정/대규모 작업이 필요해 의도적으로 남긴 것들이다.

## A. 서버 재배포 필요 (사용자가 SQL Editor / CLI에서)
1. **claim_device v2 재실행** — `supabase/schema_auth.sql` (마켓 테이블 포함 + 좋아요/참가/멤버십 행단위 충돌 병합). 미실행 시: 로그인 후 기존(익명) 매물을 본인이 수정/삭제 못 하고, 1매물 제한 우회.
2. **delete-account 재배포** — `supabase/functions/delete-account` (활성 매물 판매완료 처리 추가). `supabase functions deploy delete-account`.
3. ✅ **(코드 완료, 배포 대기)** Storage 버킷 RLS 강화 — `supabase/schema_hardening.sql`(소유 폴더만 insert/delete). 앱 uploadPhoto/deletePhoto가 경로·헤더를 ownerID로 정합. **SQL Editor에서 실행 필요.**
4. ⏳ **crew_push_token / crew_waitlist RLS** — 보류(기기단위 테이블 vs 공용 ownerID 헤더 불일치 → 적용 시 로그인 정상동작 막힘). device 전용 헤더로 클라 수정 후 잠글 것. schema_hardening.sql 하단 주석 참고. (위험: 중간)
5. ✅ **(코드 완료, 배포 대기)** notify-crew-open 중복 발송 — 원자 게이트(`update ... where opened=false returning`)로 교체. **`supabase functions deploy notify-crew-open` 재배포 필요.**
6. ✅ **(코드 완료, 배포 대기)** APNs 410 정리 — 410 응답 토큰 행 삭제 추가. 위 함수 재배포에 포함.

## B. 제품 결정/대규모 작업 필요
7. ✅ **(해결, 2026-06-13)** 마켓 1:1 채팅 공개방 문제 — `(item_id, buyer)` 스레드 + 참가자 전용 RLS(해당 구매자/그 매물 판매자만)로 재설계 완료. 판매자 문의 스레드 목록(MarketThreadListSheet) UI 추가. 메시지 사용자 삭제 불가(증거 보존), 운영자 service_role 전체 열람(→ `docs/OPERATOR_LEGAL.md`). **⚠️ `schema_market.sql` 재실행 필요**(buyer 컬럼+새 RLS) — 미배포 시 라이브 마켓 채팅 깨짐.
8. **BackupService 메모리** — 전체 사진/영상을 메인스레드에서 RAM으로 로드 후 plist 인코딩 → 사진 많은 사용자(수 GB)에서 워치독 킬. 스트리밍 zip(파일 복사 후 압축)으로 전환 필요.
9. **App Group 미활성** — 위젯↔앱 데이터 공유 entitlement 주석 처리(`project.yml`) + 그룹ID가 레거시 `group.com.babylog.app`. 유료 계정에서 켜고 그룹ID 확정 필요(켜기 전엔 위젯이 정직한 빈 상태 — 이미 처리됨).
10. **Dynamic Type 전면 미지원** — `AppFont`가 모두 고정 size. 접근성 원칙상 text style/relativeTo 마이그레이션 필요(점진).

## C. 남은 소소한 P2 (영향 작음)
- 성장차트 "최근 2개월"이 실제로는 직전 2개 측정 델타(라벨/계산 불일치); "현재 키/몸무게"가 최신 기록에 해당 항목 없으면 "–"(이전 값 있어도).
- 가계부: 아이 미등록 시 신생아 지원금 목록 노출(빈 상태 안내와 모순).
- 홈 "1년 전 오늘" 히어로 카드가 비활성(탭 동작 없음·플레이스홀더); 대시보드 타일은 정상.
- 성장 기록 삭제 UI 없음(`deleteGrowthRecord` 호출처 0).
- 소수점 콤마 입력("8,5") 파싱 실패 가능 로케일.
- 위젯/AuthStore/성장밴드 판정 단위 테스트 공백.

> 우선순위: **B-7(채팅 개인정보)** 과 **A(서버 RLS/배포)** 가 출시 전 가장 중요. A는 토큰 재발급 또는 사용자가 직접 실행해야 함.
