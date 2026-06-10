# BabyLog 변경 이력 (CHANGELOG)

> 마지막 갱신: 2026-06-10  
> 입력 기준: `process.md` 실행 로그 + `Tasklist.md` 라운드 보드  
> git log 미참조 — process.md 단일 소스 기준

---

## 현재 앱 상태 요약

| 항목 | 현황 |
|---|---|
| **화면** | 5탭 전부 실화면 완성 (홈·기록·동네·가계부·내정보) |
| **테스트** | 171개 전량 통과 (PASS 100%) |
| **커밋** | 8커밋 (main 브랜치) |
| **실기기** | iPhone "Moon" (iOS 26.5.1) 설치·실행 확인 |
| **배경색** | 흰색 `#FFFFFF` 고정 (라이트 모드, 오너 요청) |
| **디스플레이 모드** | 라이트 모드 고정 (`UIUserInterfaceStyle=Light`) |
| **프레임워크** | Swift/SwiftUI (iOS 26 Liquid Glass 네이티브) |
| **WidgetKit** | 오늘 할 일·아이 요약·주변 응급 위젯 추가 예정 (라운드 7) |

### 남은 백로그 (v1 → v2 이후)

- **CoreData + CloudKit** 실영속화 (현재 인메모리 + Codable 자동저장)
- **외부 API 실연동** (질병청·카카오맵·심평원·복지로 현재 Mock 스텁)
- **SPM 모듈화** — BLCore·BLData·BLGrowth 등 패키지 분리
- **다크 모드 재정비** — 배경색 `#FFFFFF` 고정 이후 다크 팔레트 토큰 재조정 필요
- **App Group 위젯 공유** — WidgetKit 타깃과 앱 간 AppStore 데이터 공유 (App Group 컨테이너)
- **Pretendard Variable** 폰트 번들 (현재 시스템 폰트 근사)
- **접근성 완성** — 야간 초저휘도 모드, 조부모 심플 뷰 토글

---

## 라운드 7 — 배경색·엔진 UI 연결·실사진·WidgetKit (진행중 · 2026-06-10)

> **테스트 목표**: 171개 → 예정 (위젯·UI 연결 테스트 추가 후 팀장 통합 build/test 예정)

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `DesignSystem/AppColors.swift` 外 전 화면 | 배경색을 `#FFFFFF` (순백) 로 통일. `AppColors.background` 토큰 갱신. Liquid Glass 글래스 레이어와 대비 강화. |
| `Features/Home/HomeScreen.swift` | `PriorityEngine` → 홈 "지금 가장 중요한 것" 카드 와이어링 완료. 엔진 출력(`PriorityItem`)을 카드 UI에 바인딩. |
| `Features/Profile/ProfileScreen.swift` | `BadgeEngine` → 뱃지 그리드 UI 연결. 7종 뱃지 실시간 부여 반영. |
| `Features/Profile/ProfileScreen.swift` (내보내기) | `DataExporter` → 내정보 탭 "데이터 내보내기" 버튼 진입점 연결. `ShareLink` / `UIActivityViewController` 경유 JSON 공유. |
| `Features/QuickRecord/QuickRecordSheet.swift` | 빠른기록 시트에 **PhotosUI** `PhotosPicker` 통합 — 실기기 사진 라이브러리에서 사진 선택 후 기록 첨부. |
| `Features/ShareCard/ShareCardView.swift` | 성장카드에 **PhotosUI** `PhotosPicker` 통합 — 아이 실사진 선택 → 카드 합성(`ImageRenderer.renderCard`). |
| `BabyLogWidget/` (신규 타깃) | **WidgetKit** 위젯 타깃 추가. `project.yml` 에 Widget Extension 타깃 추가. |
| `BabyLogWidget/TodayTaskWidget.swift` | "오늘 할 일" 위젯 — 임박 예방접종·기록 권유 등 PriorityEngine 상위 1건 표시. |
| `BabyLogWidget/BabySummaryWidget.swift` | "아이 요약" 위젯 — 아이 이름·월령·최근 기록 한 줄 요약. |
| `BabyLogWidget/NearbyEmergencyWidget.swift` | "주변 응급" 위젯 — 저장된 응급실 즐겨찾기 1건 빠른 호출. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **배경색 #FFFFFF** | 앱 전역 배경을 순백으로 고정. 기존 회색 계열 `systemBackground` 대비 더 밝고 선명한 카드 층위 표현. |
| **엔진 UI 3종 연결** | 라운드 6에서 ready 상태였던 PriorityEngine·BadgeEngine·DataExporter를 각 화면에 실제 바인딩. |
| **PhotosUI 실사진 picker** | `PHPickerViewController` 기반 `PhotosPicker` — 빠른기록 및 성장카드 두 곳에서 실기기 사진 첨부 가능. |
| **WidgetKit 3종** | App Extension 타깃 신규 추가. 오늘 할 일·아이 요약·주변 응급 3종 위젯. App Group 데이터 공유는 후속(백로그). |

### 팀장 통합 예정

- Widget Extension `project.yml` 타깃 추가 + App Group entitlement 기초 설정
- 위젯 3종 빌드 검증 + 시뮬레이터 위젯 갤러리 확인
- 전체 build+test PASS 확인 후 iPhone 재설치

---

## 라운드 6 — 알림 스케줄링·우선순위 엔진·뱃지 엔진·데이터 내보내기 (완료 · 2026-06-10)

> **테스트**: 111개 → **171개** (+60, 엔진 4종 테스트 60개 추가) · build+test **171/171 PASS**

### 산출물

| 파일 | 내용 |
|---|---|
| `Notifications/NotificationScheduler.swift` | 예방접종 D-7 / D-1 / 당일(D-0) 알림 요청 순수 빌더. `LocalNotificationRequest` 값 타입. 부수효과 없음, UNUserNotificationCenter 직접 참조 금지. |
| `Notifications/NotificationCenterClient.swift` | UNUserNotificationCenter 래퍼 — 권한 요청·등록·취소 담당 (구체 구현 분리). |
| `Features/Home/PriorityEngine.swift` | 홈 "지금 가장 중요한 것" 단일 카드 선정 엔진 (SPEC 기능 10). 규칙: ①임박 접종(0~7일) → ②정부지원금 → ③기록권유 → ④추억. 순수 함수, 테스트 주입 가능. |
| `Features/Profile/BadgeEngine.swift` | 활동 지표 기반 뱃지 자동 부여 엔진 (SPEC 7.3). 7종 뱃지(기록시작·30일연속·육아고수·나눔천사·거래50·첫크루·맘인플루언서). `Set<String>` 반환, 순수 함수. |
| `Data/DataExport.swift` | 데이터 주권(CLAUDE.md) 구현체. `exportJSON` / `importJSON` 라운드트립 + `exportToTemporaryFile`. ISO 8601·prettyPrinted·sortedKeys. CoreData 전환 후 API 계약 유지 예정. |

### 팀장 통합 완료

- 알림 권한 요청 + 예방접종 리마인더 → **앱 런치 연결** (UNPendingScheduler) ✅
- 우선순위 엔진·뱃지 엔진·데이터 내보내기 → 테스트 완료·available (UI 진입점 연결은 라운드 7)
- 과학적 토론(해소): `PriorityItem.referenceId` 추가 · DataExport 테스트 UUID 코드 수정 · `vaccineReminders` fireDate 전역 정렬 (QA 예측 적중)

---

## 라운드 5 — 가계부·내정보·임신기록·마켓·크루 (완료 · 2026-06-10)

> **테스트**: 87개 → **111개** (+24, 컴파일 버그 0)

### 산출물

| 화면 / 파일 | 내용 |
|---|---|
| `Features/Budget/BudgetScreen.swift` | 도넛 차트·정부지원금 전면 카드·BudgetSummary 컴포넌트 |
| `Features/Profile/ProfileScreen.swift` | 티어 진행바·뱃지 컬렉션·Pro 업셀·TierCalculator 연동 |
| `Features/Pregnancy/PregnancyRecordScreen.swift` | 태아 가이드·태동 카운터·체중 차트·배사진 D라인·산전검사 + BirthTransitionView |
| `Features/Dongne/MarketScreen.swift` | 동네 마켓 화면 |
| `Features/Dongne/CrewScreen.swift` | 크루 콜드스타트 기대감 UI |
| `Tests` (QA) | BudgetSummary·TierCalculator 테스트 19개 |

### 셸 와이어링

- 5탭 전부 실화면 완성: `BudgetTab` → `BudgetScreen` · `ProfileTab` → `ProfileScreen` · `DongneTab`(마켓→`MarketScreen`·크루→`CrewScreen`) · 임신모드 기록탭 → `PregnancyRecordScreen`
- iPhone "Moon" 재설치·실행 완료

---

## 라운드 4 — 동네·외부 API 스텁·영속화·라이트 모드·실기기 설치 (완료 · 2026-06-10)

> **테스트**: 61개 → **87개** (+26)

### 산출물

| 파일 | 내용 |
|---|---|
| `Features/Dongne/NearbyScreen.swift` | 동네 주변 화면 |
| `Features/Dongne/EmergencyScreen.swift` | 응급 다크 풀스크린 (`fullScreenCover`) |
| `Networking/` | 외부 API 스텁 4종 (질병청·카카오맵·심평원·복지로 Mock) |
| `Data/AppStore.swift` | autosave / restore 자동연결 + SampleData |

### 주요 결정 및 해결

| 항목 | 내용 |
|---|---|
| **라이트 모드 고정** | `Info.plist UIUserInterfaceStyle=Light` (오너 요청) |
| **실기기 설치** | 팀 ID `R3K972V8DA`(세션 없음) → `QN975MTM7H`(kyeongju Moon) 정정 후 `devicectl` 설치 성공 |
| **버그 해소** | networking `public`↔internal 충돌 / `mockPlaces` 파일프라이빗 접근 → 수정 |

---

## 라운드 3 — 온보딩·빠른기록·성장카드·인프라 (완료 · 2026-06-10)

> **테스트**: 43개 → **61개** (+18)

### 산출물

| 파일 | 내용 |
|---|---|
| `Features/Onboarding/` | 온보딩 5단계 (임신/출산 분기, 강제 입력 0) |
| `Features/Home/PregnancyHomeView.swift` | 임신 모드 홈 화면 |
| `Features/QuickRecord/QuickRecordSheet.swift` | 빠른기록 시트 (2탭 완료 UX + 보상) |
| `Features/ShareCard/ShareCardView.swift` | 성장카드 공유 (`ImageRenderer.renderCard`) |
| `Core/AgeCalculator.swift` | 입력 검증 강화 (LMP > 오늘, 미래 birthDate 차단) |
| `Core/EventBus.swift` | `init` 개방 — 테스트 격리 주입 지원 |
| `Data/AppStore.swift` | 버스 주입 + snapshot/restore |
| `Data/Persistence/LocalPersistence.swift` | Codable 기반 로컬 영속화 |

### 셸 와이어링 (팀장)

- 온보딩 게이트: `@AppStorage` 기반 최초 실행 감지
- FAB → `QuickRecordSheet` (`.sheet` detents)
- 좌하단 모드 전환 Liquid Glass 칩 → `PregnancyHomeView`

### 과학적 토론 해소

- `ShareCard` 문자열 따옴표 미이스케이프 컴파일 에러 → 수정

---

## 라운드 2 — 상실 알림 차단·원자 전환·기록 화면 (완료 · 2026-06-10)

> **테스트**: 27개 → **43개** (+16)

### 산출물

| 파일 | 내용 |
|---|---|
| `Notifications/NotificationService.swift` | EventBus `.pregnancyEndedInLoss` 구독 → 즉시 알림 취소. 식별자 prefix: `"preg-<id>"`. `NotificationScheduling` 프로토콜(Mock 교체 가능). |
| `Data/AppStore.swift` | `commitBirthTransition` 원자적 커밋 — 검증 실패 시 양쪽 배열 무변경 보장 |
| `Features/Record/RecordScreen.swift` | 타임라인·성장차트(Swift Charts WHO밴드+안심메시지)·예방접종 세그먼트 |

### 과학적 토론 해소

- `AppStore.commitBirthTransition` guard-else fall-through 컴파일 에러 → switch 문으로 정리 (팀장 통합 수정)

### 디버거 후속과제 충족

- 상실 알림 자동 차단 (민감 영역 최우선 1위험) ✅
- Pregnancy→Child 전환 원자성 (B2, 도메인 레벨 무변경 보장) ✅

---

## 라운드 1 — Core / Data 파운데이션 (완료 · 2026-06-10)

> **테스트**: 스펙 확인 → **27개** (빌드+테스트 첫 통과)

### 산출물

| 파일 | 내용 |
|---|---|
| `Core/AgeCalculator.swift` | 임신 주수(`pregnancyWeeks`)·아이 월령(`childAgeMonths`)·D+일·출산 D-day. EDD 우선·LMP 폴백. |
| `Core/Models.swift` | `Pregnancy / Child / GrowthRecord / DiaryEntry / VaccineRecord`. `Identifiable·Codable·Equatable`. `PregnancyStatus` enum 4상태. |
| `Core/PregnancyTransition.swift` | 순수 함수 `makeChild(from:input:)`. 3단계 검증. `Result<Child, BirthTransitionError>`. |
| `Core/EventBus.swift` | Combine `PassthroughSubject` 싱글톤. 3개 이벤트(`milestoneAchieved / recordSaved / pregnancyEndedInLoss`). |
| `Data/AppStore.swift` | 인메모리 스토어. 원자적 전환 기반 확립. |
| `Tests/BabyLogTests/` | AgeCalculatorTests 15 + PregnancyTransitionTests 12 = 27개 |

### 과학적 토론 해소

- QA 테스트가 이름 검증 결함(`"\n"` 통과) 적발 → `.whitespacesAndNewlines`로 수정 → 27/27 PASS

---

## 파운데이션 구현 — Flutter→Swift 전환 · 디자인 시스템 · 셸 (완료 · 2026-06-10)

> **빌드**: iOS 26 SDK, arm64+x86_64 시뮬레이터 BUILD SUCCEEDED

### 주요 결정: Flutter → Swift/SwiftUI 전환

| 항목 | 내용 |
|---|---|
| **결정** | Flutter 스캐폴드 생성 후 오너 지시로 **Swift/SwiftUI 최종 확정** |
| **근거** | iOS 26 Liquid Glass = SwiftUI 네이티브 `.glassEffect`/`TabView`가 가장 충실. Xcode 26.5 환경. |
| **처리** | Flutter 산출물 전량 제거 |

### 디자인 시스템 산출물

| 파일 | 내용 |
|---|---|
| `DesignSystem/AppColors.swift` | 색상 토큰 라이트·다크 적응형 (UIColor dynamic provider). 뱃지 7색 `BadgeTone` enum. |
| `DesignSystem/AppTypography.swift` | 9단계 타이포 스케일 `AppFont` enum. Pretendard Variable TODO. |
| `DesignSystem/AppMetrics.swift` | 간격 9단계·라운드 6단계·그림자 4종 (따뜻한 톤). |
| `DesignSystem/LiquidGlass.swift` | iOS 26 `.glassEffect` 네이티브 + iOS 25 이하 `.ultraThinMaterial` 자동 폴백. |
| `DesignSystem/LiquidButton.swift` | 광택 메니스커스 + 4.6s 흐르는 빛 띠 루프. `@Environment(\.accessibilityReduceMotion)` 자동 대응. |
| `Components/BLComponents.swift` | `BLCard / BLBadge / BLChip / BLSectionHead / PhotoPlaceholder` |

### 셸 산출물

| 파일 | 내용 |
|---|---|
| `Shell/MainTabView.swift` | `AppTab` enum 5탭. `AppMode` enum (`.baby / .pregnancy`). iOS 26 시스템 Liquid Glass 탭바 자동 적용. |
| `Shell/QuickRecordFAB.swift` | 우하단 스피드다이얼 FAB. 45° 회전 애니메이션. 홈·기록·동네에서만 노출. |

---

## 스펙 v0.2 업데이트 & 오너 결정 (완료 · 2026-06-10)

### 스펙 변경 내용

- **네비게이션 확정**: 3축 IB → **5탭 하단 네비(홈·기록·동네·가계부·내정보) + 우하단 FAB 스피드다이얼**
- SPEC에 **기능 8 '정보구조 & 네비게이션' 신설** (5탭 구조 / 핵심 설계 원칙 / 동네 탭 세그먼트 / FAB / 화면 간 이동)
- 기존 기능 8~14 → **9~15로 재번호** (본문 교차참조 2곳 정정)

### 오너 결정 (확정)

| 항목 | 결정 |
|---|---|
| **A1** (무광고 vs v3 브랜드 배너) | **보류** — v1 비차단, 추후 적용 |
| **A2** (성별 중립 vs 골든 맘) | **해소** — '골든 파파' 추가, 최상위 티어를 '골든 맘/골든 파파' 호칭 선택형(중립 옵션 가능). SPEC 7.2 반영 완료. |
| **D3** ('기록 멈춤' 임계값) | **확정** — 미접속 **30일**로 자동 억제 임계값 고정. 강제 토글 없이 따뜻한 권유 알림. |

---

## Phase 0 — 팀 세팅 & 스펙 확인 (완료 · 2026-06-10)

### 수행 내용

- git 저장소 초기화 (branch: `main`)
- 팀 조정 인프라: `team/TEAM.md` (팀 헌장) · `Tasklist.md` (진행 추적 보드) · `process.md` (실행 로그)
- 스펙 정독: `CLAUDE.md` (제품 철학·절대 원칙·민감 영역·아키텍처 규칙) + `SPEC.md` (기능 1~14 + 부록 A/B/C + 수익 로드맵)
- 팀원 4인 스펙 확인 병렬 수행 (Coder·Debugger·QA·Perf/Doc) → 확인서 `team/confirmations/` 작성

### 핵심 발견

| 역할 | 발견 |
|---|---|
| **Coder** | 8개 엔티티 정리, `Child.pregnancyId` 외래키 승계 구조, SPM 모듈 경계 제안 |
| **Debugger** | 최고위험: ① Pregnancy→Child 전환 원자성 ② '기록 멈춤' 트리거 미정 ③ CloudKit 동시편집 무음소실 |
| **QA** | 우선 테스트: 데이터 승계·주수/월령 계산·WHO 백분위+예방접종 스케줄. 원칙 충돌 2건 발견 (A1·A2). |
| **Perf/Doc** | 핫스팟: 사진 타임라인 스크롤(썸네일 캐시)·카드 합성(2단계)·외부 API 과호출(디바운싱). 문서 5분할 제안. |

### 오픈 질문 보드 수립

- **A (오너 판단)**: A1 무광고·광고, A2 성별 중립
- **B (아키텍처)**: B1 SPM 모듈 경계, B2 Pregnancy.status enum, B3 CloudKit 충돌 정책, B4 API 키 관리
- **C (디자인)**: C1 배사진/성장사진 혼합 타임라인, C2 썸네일 크기, C3 FAB 비주얼
- **D (계산 컨벤션)**: D1 임신 주수, D2 월령, D3 '기록 멈춤'

---

## 테스트 수 추이

| 시점 | 테스트 수 | 내용 |
|---|---|---|
| Phase 0 (스펙 확인) | 0 | 빌드·테스트 인프라 미구축 |
| 라운드 1 (Core/Data) | **27** | AgeCalculator 15 + PregnancyTransition 12 |
| 라운드 2 (상실알림·원자전환·기록) | **43** | +16 (알림 차단·원자성) |
| 라운드 3 (온보딩·빠른기록·성장카드·인프라) | **61** | +18 (검증·버스격리·영속화) |
| 라운드 4 (동네·외부API·영속화·라이트모드) | **87** | +26 (네트워킹·영속화 자동연결) |
| 라운드 5 (가계부·내정보·임신기록·마켓·크루) | **111** | +24 (BudgetSummary·TierCalculator) |
| 라운드 6 (알림스케줄·우선순위·뱃지·내보내기) | **171** | +60 (엔진 4종: NotificationScheduler·PriorityEngine·BadgeEngine·DataExporter) |
| 라운드 7 (배경색·엔진 UI·실사진·WidgetKit) | **예정** | 위젯·UI 연결 테스트 추가 후 확정 |

---

## 핵심 아키텍처 결정 모음

| 결정 | 내용 |
|---|---|
| **프레임워크** | Swift/SwiftUI (iOS 17+ 배포, iOS 26 Liquid Glass 네이티브) — Flutter 대비 SwiftUI `.glassEffect` 우위로 확정 |
| **상태 관리** | `AppStore` 인메모리 + Combine EventBus. CoreData+CloudKit 영속화는 백로그. |
| **민감 영역 1위험** | `pregnancyEndedInLoss` 이벤트 → 즉시 알림 취소. 테스트 교차검증 필수. |
| **전환 원자성** | `commitBirthTransition` 검증 실패 시 `pregnancies`·`children` 양쪽 배열 무변경 보장. |
| **계산 컨벤션** | EDD 우선·LMP 폴백. 월령 Calendar 기반 개월수 + D+N일 병기. 기록 멈춤 임계값 30일. |
| **성별 중립** | 최상위 티어 '골든 맘/골든 파파' 호칭 선택형. 중립 옵션 제공. |
| **무광고 (A1)** | v1 비차단, v3 브랜드 배너(직계약) 방향 보류. 추후 오너 최종 결정. |
