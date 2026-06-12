# 운영자 가이드 — 거래 분쟁·수사 협조 (채팅/신고 기록 제출)

거래 사고(사기·협박·안전 위협) 발생 시 운영자가 **적법한 절차**에 따라 대화·신고 기록을 수사기관에 제출하기 위한 절차와 데이터 구조. (CLAUDE.md: 신뢰·안전, 아동 안전 / 정직한 운영)

## 1. 무엇이 서버에 보존되나

| 데이터 | 테이블 | 보존/특성 |
| --- | --- | --- |
| 1:1 거래 채팅 | `public.market_chat_message` | 스레드 = (item_id, buyer). **사용자 삭제 불가**(delete 정책 없음) → 증거 보존. 매물 삭제 시 cascade로 사라질 수 있음(아래 2 주의). |
| 신고 + 대화 스냅샷 | `public.market_report` | **신고 시점 대화 전체를 jsonb로 영구 보존.** item_id가 text(FK 아님) → **매물이 삭제돼도 남음.** 운영자 전용(SELECT 정책 없음). |

**프라이버시 원칙**: 일반 사용자는 RLS로 자기 1:1 스레드만 열람. 운영자는 `service_role`로 RLS를 우회해 전체 열람(아래 3). 아동·개인정보는 비저장(익명 기기ID/auth.uid + 닉네임 + 본문만).

## 2. 가장 견고한 증거 = 신고 스냅샷(market_report)
구매자/판매자가 채팅 화면 → 메뉴 → **거래 신고**를 하면, 그 시점 대화 전체가 `market_report.transcript`(jsonb)로 **불변 보존**된다. 매물·채팅이 이후 삭제돼도 이 스냅샷은 남으므로 **분쟁/수사 대응의 1차 법적 기록**이다. (앱: `MarketBackend.uploadReport`, 실패 시 재시도)
> 권장: 라이브 채팅(`market_chat_message`)은 매물 cascade로 유실 가능하므로, 사고 의심 시 **신고를 유도**해 스냅샷을 남기게 한다. (장기적으로 chat을 set null 보존으로 전환 검토 — KNOWN_ISSUES.)

## 3. 운영자 열람·내보내기 (service_role)
RLS는 일반 키(anon/사용자)에만 적용된다. **운영자는 Supabase Dashboard(소유자 로그인)** 에서 SQL Editor/Table Editor로 `service_role` 권한으로 전체 조회한다. (service_role 키는 절대 앱/깃에 넣지 않음 — 대시보드/서버 전용)

### 특정 거래의 대화 전체 내보내기
```sql
-- 매물 + 구매자로 1:1 스레드 추출(시간순)
select created_at, device_id as 작성자, author_name as 닉네임, body as 내용
from public.market_chat_message
where item_id = '<UUID>' and buyer = '<buyer id>'
order by created_at;
```
### 신고 스냅샷 추출(가장 권장 — 불변 증거)
```sql
select created_at, item_title, reason, note, transcript
from public.market_report
where item_id = '<item id>'      -- 또는 reason/기간으로 필터
order by created_at desc;
```
대시보드 결과를 **CSV/JSON 내보내기**하여 수사기관 공식 요청(영장·수사 협조 공문)에 첨부 제출.

## 4. 적법 절차 / 정책 (출시 전 확정)
- **제출 트리거**: 수사기관의 적법한 요청(영장 또는 수사 협조 공문)에만 제출. 임의 열람 금지.
- **감사 로그**: 운영자 열람·내보내기 이력을 별도 기록(누가·언제·무엇을). (추후 admin 콘솔/감사 테이블)
- **보관 기간**: 신고 스냅샷은 분쟁 시효 고려해 보관, 그 외 채팅은 정책상 기간 후 정리(미확정).
- **고지**: 개인정보처리방침에 "거래 분쟁/수사 협조 시 적법 절차에 따라 대화 기록이 제출될 수 있음" 명시. 신고 화면 카피에 이미 반영됨("적법한 절차에 따라 제출될 수 있어요").
- **service_role 키 보안**: 유출 시 전체 데이터 노출 → 대시보드 외 사용 금지, 노출 의심 시 즉시 로테이트.

## 5. 향후 강화(KNOWN_ISSUES 연계)
- admin 전용 Edge Function으로 내보내기 + 감사 로그 자동화.
- market_chat_message를 매물 삭제와 독립 보존(set null)로 전환 검토.
- 신고 누적 사용자 자동 제한/차단.
