# BabyLog 아키텍처 가이드

> 최종 업데이트: 2026-06-10 · 입력: `SPEC.md` 부록 B, `CLAUDE.md`, `team/DESIGN_REVIEW.md`, `App/Sources/`

---

## 1. 정보구조 (IA) — 5탭 구조

BabyLog는 5개 하단 탭으로 전체 기능을 구성합니다. 중앙 탭바 FAB는 채택하지 않습니다.

```
홈          기록         동네         가계부       내정보
(요약·진입) (타임라인)  (지역통합)   (지출·지원금) (프로필·뱃지)
```

### 탭별 역할

| 탭 | 역할 | 핵심 내용 |
|---|---|---|
| **홈** | 요약·진입점 | 우선순위 엔진 단일 카드, 다자녀 칩, 응급 버튼 |
| **기록** | 아이 타임라인 | 타임라인/성장차트/예방접종 세그먼트 (임신 모드 별도) |
| **동네** | 지역 통합 (주변·마켓·크루) | 시간대 적응형 노출 (밤=소아과, 낮=마켓 우선) |
| **가계부** | 육아비 + 정부지원금 | 정부지원금 전면 배치, 자동 수집 대시보드 중심 |
| **내정보** | 계정·신뢰 | 프로필 카드·뱃지 컬렉션·Pro 업셀·데이터 원칙 |

### 포함 기능 8개

기능 8(정보구조 & 네비게이션)이 전체 뼈대이며, 기능 1~7이 각 탭 내부에 위치합니다.

```
기능 1 임신 기록        → 기록 탭 (임신 모드)
기능 2 성장 기록        → 기록 탭 (육아 모드)
기능 3 주변 인프라·응급  → 동네 탭 > 주변 세그먼트
기능 4 중고 마켓        → 동네 탭 > 마켓 세그먼트 (v2~)
기능 5 가계부           → 가계부 탭
기능 6 동네 크루        → 동네 탭 > 크루 세그먼트 (v3~)
기능 7 뱃지 & 신뢰도    → 내정보 탭 + 마켓·채팅 전체
기능 8 정보구조·네비     → 앱 전체 셸 (MainTabView + FAB)
```

---

## 2. 네비게이션 아키텍처

### 2.1 MainTabView + QuickRecordFAB

- **파일**: `App/Sources/Shell/MainTabView.swift`
- iOS 26에서 `TabView`는 시스템 Liquid Glass 탭바로 렌더됩니다.
- `AppTab` enum: `.home | .record | .dongne | .budget | .profile`
- `AppMode` enum: `.baby | .pregnancy` — 기록 탭과 FAB 액션을 분기합니다.

```swift
// MainTabView 핵심 구조
ZStack(alignment: .bottomTrailing) {
    TabView(selection: $tab) { /* 5개 탭 */ }
    if tab == .home || tab == .record || tab == .dongne {
        QuickRecordFAB(mode: mode)  // 홈·기록·동네에서만 노출
    }
}
```

### 2.2 빠른 기록 FAB (QuickRecordFAB)

- **파일**: `App/Sources/Shell/QuickRecordFAB.swift`
- 위치: 우하단 고정 (설정에서 좌하단으로 이동 가능 — 왼손잡이 접근성)
- 탭하면 스피드다이얼이 위로 펼쳐지고 버튼은 45° 회전
- 모드별 액션 분기:
  - **육아 모드**: 성장 측정 / 사진 / 메모
  - **임신 모드**: 태동 / 배 사진 / 메모
- 사진 1장 → 저장: **2탭 완료** (핵심 UX 지표)

### 2.3 화면 이동 규칙

| 이동 유형 | 방식 |
|---|---|
| 탭 전환 | IndexedStack으로 각 탭 상태(스크롤·필터) 보존 |
| 상세 화면 | push (우→좌 슬라이드) |
| 시트/모달 | 바텀시트 (slideUp) |
| 응급/Pro/공유 | 다크 풀스크린 |
| 딥링크 | 홈 카드/알림 → 해당 탭 상세로 직접 이동 |

---

## 3. 디자인 시스템 레이어

```
design/handoff/design_files/babylog-ds.css   ← 토큰 원본 (CSS 변수)
        │
        ▼ Swift 이식
App/Sources/DesignSystem/
├─ AppColors.swift      색상 토큰 (라이트/다크 적응형 UIColor 브릿지)
├─ AppTypography.swift  타이포 스케일 9단계 (AppFont enum)
├─ AppMetrics.swift     간격(Spacing) · 라운드(Radius) · 그림자(BLShadowKind)
└─ LiquidGlass.swift   시그니처 iOS 26 glassEffect + 폴백

App/Sources/Components/
├─ BLComponents.swift   BLCard · BLBadge · BLChip · BLSectionHead · PhotoPlaceholder
└─ LiquidButton.swift  시그니처 리퀴드 CTA (광택 메니스커스 + 흐르는 빛 띠)
```

프로덕션 단계에서는 `AppColors`의 코드 기반 색상을 **Asset Catalog named color**로 이관합니다 (`DESIGN.md §2.4`).

---

## 4. 공통 이벤트 버스 (부록 B)

기능 간 연결을 초기부터 표준화해 v2 대규모 리팩터링을 방지합니다.

- **파일**: `App/Sources/Core/EventBus.swift`
- 구현: Combine `PassthroughSubject<AppEvent, Never>` 싱글톤

```swift
// 이벤트 정의 (AppEvent enum)
case milestoneAchieved(childId: UUID, milestone: String)
case recordSaved(childId: UUID)
case pregnancyEndedInLoss(pregnancyId: UUID)

// 발행
EventBus.shared.publish(.milestoneAchieved(childId: id, milestone: "첫 걸음마"))

// 구독
EventBus.shared.events
    .sink { event in /* 추천 트리거 등 처리 */ }
    .store(in: &cancellables)
```

### 이벤트 버스 활용 시나리오

| 이벤트 | 트리거 | 반응 예시 |
|---|---|---|
| `milestoneAchieved` | 이정표 달성 기록 | 마켓에서 관련 월령 매물 추천 |
| `recordSaved` | 사진 저장 | 홈 리텐션 카운터 갱신 |
| `pregnancyEndedInLoss` | 상실 기록 | 모든 임신 알림 즉시 중단 |

---

## 5. 데이터 모델 — Pregnancy → Child 승계

임신 기록(Pregnancy)이 출산 시점에 아이(Child)로 매끄럽게 이어집니다. 태아 시절 배 사진·태명·임신 기록은 아카이브로 영구 보존됩니다.

### 핵심 엔티티

| 엔티티 | 파일 | 주요 필드 |
|---|---|---|
| `Pregnancy` | `Data/Models.swift` | `id · lmpDate · eddDate · fetusCount · nickname · clinic · status` |
| `Child` | `Data/Models.swift` | `id · name · birthDate · gender · profileImageRef · caregiverRole · pregnancyId` |
| `GrowthRecord` | `Data/Models.swift` | `id · childId · date · heightCm · weightKg · headCircumferenceCm` |
| `DiaryEntry` | `Data/Models.swift` | `id · childId · date · recordType · content · milestone` |
| `VaccineRecord` | `Data/Models.swift` | `id · childId · vaccineId · scheduledDate · completedDate · hospital` |

### PregnancyStatus enum

```swift
case active     // 임신 진행 중
case delivered  // 출산 완료 (→ Child 승계)
case loss       // 상실 (모든 임신 알림 중단)
case paused     // 기록 멈춤 모드
```

### 출산 전환 로직

- **파일**: `App/Sources/Data/PregnancyTransition.swift`
- `PregnancyTransition.makeChild(from:input:)` → `Result<Child, BirthTransitionError>`
- 검증 순서: ① status == .active → ② 이름 비어있지 않음 → ③ 출생일 >= LMP
- 원자성은 호출측 책임 (CoreData 트랜잭션에서 Pregnancy.status 갱신 + Child 삽입을 동시에)

```
임신 프로필 (Pregnancy)
  ├─ 배 사진 타임라인 (MaternalRecord.bellyPhoto)
  ├─ 태명 (Pregnancy.nickname)
  └─ 예정일 (Pregnancy.eddDate)
         ↓ 출산 전환 (PregnancyTransition.makeChild)
아이 프로필 (Child, pregnancyId 연결)
  ├─ 성장 사진 타임라인 (DiaryEntry) ← 배 사진과 연속
  ├─ 이름 (input.childName)
  └─ 생년월일 (input.birthDate)
```

---

## 6. SPM 모듈화 계획 (부록 B.1 — Phase 3 이후)

현재는 단일 앱 타깃으로 빌드를 우선합니다. Phase 3 본구현 이후 아래 구조로 분리합니다.

```
BLCore (이벤트 버스 · 공통 모델 · AgeCalculator)
BLDesignSystem (AppColors · AppFont · AppMetrics · LiquidGlass · Components)
BLGrowth (성장 기록 · 예방접종 · 성장 카드)
BLPregnancy (임신 기록 · 출산 전환)
BLInfra (주변 인프라 · 응급 모드)
BLMarket (중고 마켓 · 렌탈) — v2~
BLBudget (가계부 · 정부지원금) — v2~
BLCrew (동네 크루 · 커뮤니티) — v3~
```

모듈 경계는 기능 탭 단위와 일치시켜 1인 유지보수 부담을 분산합니다.

---

## 7. 외부 API & 백엔드

### 무료 공공 API (v1~)

| API | 용도 |
|---|---|
| 질병관리청 예방접종도우미 | 예방접종 스케줄 |
| 건강보험심사평가원 | 소아과·약국 정보 |
| 카카오맵 로컬 API | 주변 장소 (월 30만 건 무료) |
| 복지로 API | 아동수당·부모급여·첫만남이용권 등 |
| KATSA/KERI 리콜 DB | 카시트 등 리콜 조회 |

### Supabase 백엔드 (v2 마켓 이후)

| 기능 | Supabase 서비스 |
|---|---|
| 매물 데이터 | Postgres |
| 이미지 저장 | Storage (CDN 포함) |
| 실시간 채팅 | Realtime |
| 인증 | Auth (Apple Sign-in 연동) |
| 검색 | Postgres FTS → Algolia (MAU 5만+ 이후) |

---

## 8. 아키텍처 결정 기록

| 결정 | 내용 | 사유 |
|---|---|---|
| Flutter → SwiftUI | 최종 SwiftUI 확정 | iOS 26 Liquid Glass 네이티브 지원, SPEC 원본 스택과 일치 |
| 단일 타깃 → SPM | 현재 단일 타깃 유지 | 빌드 우선, Phase 3에서 SPM 분리 |
| CoreData + CloudKit | 로컬/가족 공유 | 온디바이스 우선 원칙, 사진 서버 비저장 |
| 중앙 탭바 FAB 미채택 | 우하단 스피드다이얼 FAB | 한 손 엄지 동선, iOS HIG 탭바 겹침 방지 |
