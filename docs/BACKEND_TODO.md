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

## 3. 크루(동네) 백엔드 🟢 거의 완료 (2026-06-12)

연결점: `CrewBackend.swift`(PostgREST URLSession), `AppStore`(로컬 폴백), `supabase/schema_crew.sql`·`schema_push.sql`.

- ✅ **모임/그룹/게시판/댓글 동기화** — 동네별 Supabase 공유(`fetchPosts/Meetups/Groups`, `create*`). 미구성 시에만 로컬/목업.
- ✅ **모임 채팅 + 게시판 댓글** — 3초 폴링(준실시간, `crew_meetup_message`/`crew_post_reply`). scenePhase 절전.
- ✅ **좋아요/가입/정원 정합** — 카운트 "나 제외" 규약 통일, 중복탭 방지+롤백, 서버 카운트 단일출처.
- ✅ **콜드스타트 대기열 + 실시간 오픈 푸시** — `crew_waitlist`/APNs Edge Function(임계값 30).
- ⏳ **남음**: Realtime 구독으로 폴링 대체(선택), 익명→Apple 로그인 + 소유자 기반 RLS(현재 `using(true)` MVP — `docs/AUTH_SETUP.md` 참조), 작성 텍스트 길이 제한·스팸 방지.

---

## 4. 가족 공유 (하이브리드 피드) 🔴 — 비용 구조 주의

연결점: `App/Sources/Data/CloudSyncService.swift`(현재 스텁).

**전략: 개인이 애플 iCloud/CloudKit(=애플 서버)에 올려 조부모가 시청. 우리 서버비 최소화.**

| 경로 | 우리 서버비 | 비고 |
|---|---|---|
| iOS 조부모 (CloudKit CKShare) | **≈ 0** | 애플 인프라+사용자 iCloud. **우선 구현** |
| 안드로이드 조부모 | **발생** | 사진·영상이 웹에서 받아져야 함(저장+대역폭, 영상이 비쌈) |

⚠️ **CloudKit 한계(정정)**: CloudKit으로 **비공개 가족 미디어**를 보려면 **애플 ID 로그인 필요** → 애플 ID 없는 **안드로이드 조부모는 접근 불가**. 공개 DB에 아이 사진을 넣는 건 프라이버시상 불가.
→ 결론: **안드로이드에 비공개 가족 영상/사진을 보여주려면 우리 스토리지/CDN 필요 = 실제 비용 발생**(영상 대역폭이 큼). "CloudKit Web이면 무료"는 비공개 미디어엔 성립 안 함.

진행:
1. **iOS 가족공유(CloudKit CKShare) 먼저** — 무료, 사용자 확보 ← 권장
2. **안드로이드/크로스플랫폼 가족 시청(영상 포함)** = 원가 있는 기능 → **이 기능만 유료(구독)** 로 도입(정직한 결제: 원가 있는 것만 과금). 가격은 스토리지+영상 대역폭 원가 커버.
3. 영상은 무거우니, 안드로이드는 사진 우선/영상은 유료에서.

→ `CloudSyncService` 실제 구현(CKShare). 무료 데이터 영구 보존 원칙 준수.

---

## 5. 결제 (StoreKit 2) — ⏸️ 보류 (전면 무료 전략)

> **결정: 당분간 구독 없음.** 전면 무료로 사용자부터 모은다. 앱 내 Pro/구독 UI는 전부 제거함
> (ProfileScreen 업셀 카드·ShareCard 워터마크 Pro 잠금·크루 "Pro 체험" 문구 삭제 완료).

- 무료라고 사진을 우리 서버에 올리지 않는다 → **사진은 계속 로컬**(서버비 0, 원칙 유지)
- 워터마크는 **무료 자유 토글**(기본 ON = 자연 바이럴)
- 나중에 재도입 시: Pro 구독은 **디지털 혜택만**(사진 iCloud 백업·정밀 백분위 등). **실물 중고거래 수수료는 StoreKit ❌ → 외부 PG/직거래**
- 사용자 규모 확보 후 재검토

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

1. **외부 4 API 키** (즉효·저비용·서버 불필요, 클라 거의 준비됨) — 접종/병원/장소/지원금 실데이터
2. **Supabase + Auth** (서버 기능 토대)
3. **마켓 서버** (매물 동기화 → 실시간 채팅 → **신고 서버 저장+관리자 콘솔**)
4. **크루 실시간** (채팅/게시판 동기화)
5. **가족 공유(CloudKit, iOS 우선·무료)** → 안드로이드는 CloudKit Web로 확장
6. **푸시 알림(APNs)**
7. **AI / 성장 백분위**
8. **정책·국제화** — 상시 병행
- ⏸️ **결제(Pro/StoreKit)** — 전면 무료 전략으로 **보류**. 사용자 규모 후 재검토

---

## 지금 클라이언트가 이미 준비해 둔 "꽂는 곳" 요약

- `ProviderFactory` — 4개 API Live/Mock 자동 분기(키만)
- `tradeReports.uploaded` + 대화 스냅샷 — 신고 서버 업로드 페이로드
- `marketChats` / `crewChats` — 실시간 채팅 전환 지점
- `CloudSyncService`(스텁) — 가족 동기화
- `Notifications/*` — 로컬/푸시 알림
- `PersistableState` / `BackupService` / `DataExport` — 백업·데이터 주권
- 피처 플래그 자리 — (미구현) 원격 구성 도입 지점
