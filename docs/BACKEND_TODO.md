# 백엔드·서버·API 전체 작업 정리 (BabyLog)

> 그동안 "api 빼고"로 미뤄둔 **서버/백엔드/외부 API** 작업을 한곳에 모았다.
> 클라이언트(SwiftUI)는 대부분 **연결 지점(시드/스텁/플래그)** 이 이미 준비돼 있어,
> 키·서버만 붙이면 동작하도록 설계돼 있다. 각 항목에 **현재 코드 연결점**을 명시한다.

범례: 🟢 클라 준비됨(키/서버만) · 🟡 클라 일부+서버 필요 · 🔴 신규(클라+서버 둘 다)

---

## 0. 공통 인프라 (가장 먼저 — 모든 것의 토대)

- 🔴 **Supabase 프로젝트 생성** — Postgres + Auth + Storage + Realtime
- 🟡 **키 주입 체계** — 현재 `APIConfig.key(...)` 유무로 Live/Mock 자동 분기(`ProviderFactory`).
  - 할 일: `.xcconfig`/Keychain로 키 안전 주입, Debug/Release 구성 분리, 키 미커밋
- 🔴 **Auth(계정)** — 온보딩 "이미 계정이 있어요" 로그인, 익명→계정 승격, 기기 간 동기화 식별자
- 🔴 **원격 구성(피처 플래그)** — 동네별 점진 개방, 심사 없는 핫픽스(서버에서 기능 on/off)

---

## 1. 외부 무료 API 4종 (가장 저비용·즉효 — 키만 발급하면 거의 끝)

> 연결점: `App/Sources/Networking/ProviderFactory.swift` (키 있으면 Live, 없으면 Mock)
> `LiveProviders.swift`에 Live 구현 골격 존재 → **응답 스키마 매핑·검증**만 남음.

| API | 키 이름(APIConfig) | Live 클래스 | 사용 화면 | 할 일 |
|---|---|---|---|---|
| 질병관리청 예방접종도우미 | `KDCA_VACCINE_API_KEY` | LiveVaccineScheduleProvider | 기록(접종)·홈 우선순위 | 키 발급 + 응답 매핑·검증 |
| 건강보험심사평가원(HIRA) | `HIRA_API_KEY` | LiveHospitalInfoProvider | 주변·응급(소아과/약국) | 키 발급 + 매핑·영업시간 |
| 카카오맵 로컬 | `KAKAO_REST_API_KEY` | LivePlaceSearcher | 주변(실좌표·거리) | 키 발급 + 좌표/거리 실연동 |
| 복지로 | `BOKJIRO_API_KEY` | LiveSubsidyProvider | 가계부(정부지원금) | 키 발급 + 지원금 목록 매핑 |

공통 할 일: 발급/할당량/이용약관 확인, 응답→모델 매핑, 에러·타임아웃·캐싱, Mock→Live 회귀 테스트, "샘플 데이터" 안내(`ProviderFactory.isMock`) 자동 해제.

부가: KATSA/KERI **리콜 DB**(카시트 등) — 마켓 상세 리콜 경고(현재 mock). 공개 데이터 확보 후 연동.

---

## 2. 마켓(거래) 백엔드 🟡

연결점: `AppStore`(marketItems/marketChats/savedMarketIds/tradeReports), `PersistableState`.

- **매물 동기화** — 등록/조회/상태(판매중·예약·완료)를 Postgres에 (현재 로컬 `marketItems`)
- **실시간 채팅(Realtime)** — 현재 로컬 `marketChats` + **데모 자동응답**. 상대방 실메시지 수신 필요
- **거래 신고·증거 서버 저장** — `TradeReport`(대화 스냅샷+`uploaded` 플래그) 이미 준비.
  - 할 일: `!uploaded` 신고 **서버 업로드**, **관리자 콘솔**(열람), **적법 제출 절차**(영장/수사협조), **감사 로그**, **보관기간 정책**
  - ⚠️ 현재는 로컬 보관만 — 관리자(운영자)가 원격으로 가져올 수 없음(서버 필요)
- **신뢰·안전** — 거래 후기/평점, 신고 누적 차단, 판매자 티어 산정
- **사진** — 무료=로컬, **Pro=서버 백업(Storage)**. 아동 사진 서버 비전송 원칙 준수
- 위치 기반 노출 + 페이지네이션(LazyVStack)

---

## 3. 크루(동네) 백엔드 🟡

연결점: `AppStore`(crews/joinedCrewIds/crewPosts/crewPostComments/crewChats/likedCrewPostIds).

- **모임/그룹/게시판/댓글 동기화** — 현재 전부 로컬
- **그룹·모임 실시간 채팅(Realtime)** — 현재 `crewChats` 로컬 + 데모
- **좋아요/가입/정원 서버 정합** — 동시성·중복 방지
- **콜드스타트 대기열(waitlist)** — 동네별 오픈(현재 DEBUG 토글 미리보기만)

---

## 4. 가족 공유 (하이브리드 피드) 🔴

연결점: `App/Sources/Data/CloudSyncService.swift`(현재 스텁).

- 부모↔조부모 **공유(피드 방식)** — 결정됨. iOS=CloudKit이지만 **안드로이드 조부모 호환** 위해 **하이브리드(서버 피드)**
- **사진/영상 시청(조부모)** — 피드/서버 필요(영상은 특히)
- CloudKit CKShare vs Supabase 피드 최종 결정 → `CloudSyncService` 실제 구현
- 무료 데이터 영구 보존 원칙 준수

---

## 5. 결제 (StoreKit 2) 🔴

- **Pro 구독** 상품 정의 + **거래 수수료**
- **Pro 게이팅**: 사진 서버백업, 성장 백분위(정밀), 매물 무제한, 서버 LLM AI, (가족 공유 일부)
- 영수증 **서버 검증**, 구독 상태 동기화
- 정직한 결제(다크패턴 금지·사전 고지·쉬운 해지) — 절대 원칙

---

## 6. 알림 (Push + Local) 🟡

연결점: `App/Sources/Notifications/`(NotificationService/Scheduler/CenterClient 존재), 온보딩에서 권한 요청 실동작.

- **로컬 알림**: 1년 전 오늘 사진(월 1회), 예방접종 D-day, 산전검진 — 스케줄 연결·검증
- **서버 푸시(APNs)**: 마켓 채팅/거래, 크루, 가족 피드 갱신
- **민감영역**: 상실 시 "기록 멈춤" → 주차/태아/권유 알림 **즉시 전면 중단**(정책 준수), 미접속 시 자동 완화

---

## 7. AI (비용 분기) 🔴

- **온디바이스 Core ML(무료)**: 사진 자동 분류·하이라이트·중복 정리 등
- **서버 LLM(Pro)**: 고급 요약/도우미
- 'AI' 단어 전면 비노출 → 매끄러운 경험으로 내재화

---

## 8. 성장 백분위 🟡

- WHO/질병청 **성장도표** 데이터 → percentile(또래 비교). **옵트인 + 안심 톤(등수 X)**
- 온디바이스 계산(무료) vs 정밀/리포트(Pro)

---

## 9. 데이터·프라이버시·신뢰안전 (정책/법무 — 상시) 🟡

연결점: `DataExport`/`BackupService`(표준 내보내기 이미 있음).

- **약관 + 개인정보 처리방침** — 거래채팅 보관기간·열람·삭제, 위치/알림 권한
- **데이터 주권** — 표준 포맷 내보내기(보유) + **계정 삭제 시 처리**(서버 데이터 포함)
- **아동 데이터 비매각 / 사진 서버 비전송 / 무료 데이터 영구 보존** — 서버 도입 시 재점검
- 신고·차단·분쟁 운영 프로세스

---

## 10. 국제화 (i18n) 🟡

- 문자열 리소스 분리(현재 일부 하드코딩) → `Localizable` → 다국어 옵션 확보

---

## 권장 진행 순서 (의존성 기준)

1. **Supabase + Auth** (기반) — 없으면 2·3·4·5가 막힘
2. **외부 4 API 키** (즉효·저비용, 클라 거의 준비됨) — 접종/병원/장소/지원금 실데이터
3. **마켓 서버** (매물 동기화 → 실시간 채팅 → **신고 서버 저장+관리자 콘솔**)
4. **결제(Pro)** — 사진 서버백업 등 수익 + 게이팅
5. **크루 실시간** (채팅/게시판 동기화)
6. **가족 피드(하이브리드)** — 조부모(안드로이드 포함) 시청
7. **푸시 알림(APNs)**
8. **AI / 성장 백분위**
9. **정책·국제화** — 상시 병행

---

## 지금 클라이언트가 이미 준비해 둔 "꽂는 곳" 요약

- `ProviderFactory` — 4개 API Live/Mock 자동 분기(키만)
- `tradeReports.uploaded` + 대화 스냅샷 — 신고 서버 업로드 페이로드
- `marketChats` / `crewChats` — 실시간 채팅 전환 지점
- `CloudSyncService`(스텁) — 가족 동기화
- `Notifications/*` — 로컬/푸시 알림
- `PersistableState` / `BackupService` / `DataExport` — 백업·데이터 주권
- 피처 플래그 자리 — (미구현) 원격 구성 도입 지점
