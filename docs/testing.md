# BabyLog 테스트 가이드

> 최종 업데이트: 2026-06-10 · 입력: `Tests/BabyLogTests/`, `App/Sources/Data/`, `App/Sources/Core/`, `App/Sources/Notifications/`, `team/debug/phase3-risk-audit.md`

---

## 1. 테스트 구조

```
Tests/
└─ BabyLogTests/
   ├─ AgeCalculatorTests.swift        # AgeCalculator 단위 테스트 (17개 케이스)
   └─ PregnancyTransitionTests.swift  # PregnancyTransition·AppStore 단위 테스트 (14개 케이스)
```

테스트 타깃: `BabyLogTests` (XCTest 프레임워크, `@testable import BabyLog`).

---

## 2. 실행법

### 기본 실행 (시뮬레이터)

```bash
# <sim>에 실제 시뮬레이터 UDID 또는 이름 입력
xcodebuild -scheme BabyLog \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           test
```

### 코드 서명 없이 실행 (CI / 로컬 빠른 확인)

```bash
xcodebuild -scheme BabyLog \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           CODE_SIGNING_ALLOWED=NO \
           test
```

### 특정 테스트 클래스만 실행

```bash
xcodebuild -scheme BabyLog \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           CODE_SIGNING_ALLOWED=NO \
           -only-testing:BabyLogTests/AgeCalculatorTests \
           test
```

### 시뮬레이터 UDID 확인

```bash
xcrun simctl list devices available
```

---

## 3. 현재 테스트 커버리지

### 3-1. AgeCalculator (`AgeCalculatorTests.swift`)

`App/Sources/Core/AgeCalculator.swift` 대상. 총 **11개 케이스**.

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_pregnancyWeeks_lmpOnly_1week` | LMP만 있을 때 1주차 계산 |
| `test_pregnancyWeeks_eddPriority` | EDD가 있으면 LMP보다 우선 적용 |
| `test_pregnancyWeeks_bothNil_returnsNil` | lmp·edd 모두 nil → nil 반환 |
| `test_pregnancyWeeks_eddOnly_noLmp` | EDD만 있을 때 정상 계산 |
| `test_pregnancyWeeks_asOfEqualsLmp_zeroWeeks` | 임신 당일 → (0, 0) |
| `test_childAgeMonths_14months5days` | 14개월 5일 계산 |
| `test_childAgeMonths_sameDay_zeroZero` | 생일 당일 → (0, 0) |
| `test_childAgeMonths_exactly1Month` | 정확히 1개월 후 → (1, 0) |
| `test_dPlusDays_birthDay_returns1` | 출생 당일 → D+1 |
| `test_dPlusDays_dayAfterBirth_returns2` | 출생 다음날 → D+2 |
| `test_dPlusDays_hundredDays_returns100` | 출생 +99일 → D+100 (백일) |
| `test_dPlusDays_fiftyDays` | 출생 +49일 → D+50 |
| `test_dDayToBirth_7daysRemaining` | EDD 7일 전 → 7 |
| `test_dDayToBirth_2daysPast` | EDD 2일 후 → -2 |
| `test_dDayToBirth_sameDay_returnsZero` | EDD 당일 → 0 |

### 3-2. PregnancyTransition (`PregnancyTransitionTests.swift`)

`App/Sources/Data/PregnancyTransition.swift` 대상. 총 **14개 케이스**.

**성공 케이스:**

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_makeChild_activePregnancy_validInput_succeeds` | 정상 입력 → success, `pregnancyId` 승계, `name` 일치 |
| `test_makeChild_genderNil_succeeds` | `gender = nil` 허용 확인 |

**NotActive 에러 케이스:**

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_makeChild_delivered_returnsNotActive` | `.delivered` 상태에서 전환 차단 |
| `test_makeChild_loss_returnsNotActive` | `.loss` 상태에서 전환 차단 (민감 영역 — 이 테스트는 반드시 통과해야 함) |
| `test_makeChild_paused_returnsNotActive` | `.paused` 상태 처리 (정책 확인 후 assertion 업데이트 필요) |

**EmptyName 에러 케이스:**

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_makeChild_whitespaceChildName_returnsEmptyName` | 공백 문자열(" ") → `.emptyName` |
| `test_makeChild_emptyChildName_returnsEmptyName` | 빈 문자열("") → `.emptyName` |
| `test_makeChild_tabAndNewlineChildName_returnsEmptyName` | 탭·개행("\t\n") → `.emptyName` |

**BirthDateBeforeLMP 에러 케이스:**

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_makeChild_birthDateBeforeLMP_returnsError` | `birthDate < lmpDate` → `.birthDateBeforeLMP` |
| `test_makeChild_birthDateEqualToLMP_boundary` | `birthDate == lmpDate` 경계값 (정책 확정 후 업데이트 필요) |
| `test_makeChild_noLMP_doesNotThrowBirthDateBeforeLMP` | `lmpDate = nil`이면 해당 에러 미발생 |

**추가 계약 검증:**

| 테스트 메서드 | 검증 내용 |
|---|---|
| `test_makeChild_consecutiveCalls_uniqueChildIds` | 연속 호출 시 `child.id` 매번 고유 UUID |

### 3-3. NotificationService — 구조 및 테스트 포인트

`App/Sources/Notifications/NotificationService.swift`의 핵심 설계: `NotificationScheduling` 프로토콜을 통해 `UNUserNotificationCenter`를 분리하므로, XCTest에서 mock을 주입해 알림 취소 호출 여부를 검증할 수 있습니다.

```swift
// Mock 예시 (테스트 작성 시 활용)
final class MockNotificationScheduler: NotificationScheduling {
    var cancelledIds: [UUID] = []
    func cancelPregnancyNotifications(pregnancyId: UUID) {
        cancelledIds.append(pregnancyId)
    }
}

// 검증 흐름
// 1. MockNotificationScheduler 생성
// 2. NotificationService(scheduler: mock, bus: bus).start()
// 3. bus.publish(.pregnancyEndedInLoss(pregnancyId: testId))
// 4. XCTAssertTrue(mock.cancelledIds.contains(testId))
```

> **현재 상태**: NotificationService 자체 테스트 파일이 아직 없습니다. Phase 3에서 반드시 추가해야 합니다 (`team/debug/phase3-risk-audit.md` C-1, 가설 H4).

### 3-4. AppStore 원자성 — 테스트 포인트

`App/Sources/Data/AppStore.swift`의 `commitBirthTransition`은 다음 시나리오를 검증해야 합니다.

| 시나리오 | 기대 결과 |
|---|---|
| 존재하지 않는 pregnancyId 입력 | `.failure(.notActive)`, pregnancies·children 무변경 |
| `.delivered` 상태 pregnancy 입력 | `.failure(.notActive)`, 무변경 |
| 빈 이름 입력 | `.failure(.emptyName)`, 무변경 (pregnancy.status도 변경 없음) |
| 정상 입력 | `.success(child)`, `pregnancies[i].status == .delivered`, `children`에 child 추가 |
| 정상 전환 후 EventBus 이벤트 확인 | `recordSaved(childId:)` 이벤트 발행 여부 |

---

## 4. 테스트 작성 컨벤션

### 4-1. 계약 기반(Contract-Based) 테스트

테스트는 구현 세부사항이 아닌 **공개 API 계약**을 검증합니다.

- 함수 시그니처(파라미터 타입·반환 타입)가 변하지 않는 한 테스트가 깨지지 않아야 합니다.
- 내부 알고리즘 변경 후 동일한 입·출력이면 테스트 수정 없이 통과해야 합니다.
- 네이밍 규칙: `test_<대상>_<조건>_<기대결과>` (예: `test_makeChild_loss_returnsNotActive`).

### 4-2. 교차 레이어 검증

BabyLog 테스트는 단일 함수가 아닌 **계층 간 연동**을 함께 검증합니다.

- `PregnancyTransitionTests`: `PregnancyTransition`(검증 계층)과 `Models`(데이터 계층) 연동 검증.
- 향후 AppStore 테스트: `AppStore`(커밋 계층) + `EventBus`(이벤트 계층) + `NotificationService`(알림 계층) 연동 검증.

### 4-3. 픽스처(Fixture) 헬퍼 활용

반복 사용되는 테스트 데이터는 헬퍼 메서드로 분리합니다.

```swift
// AgeCalculatorTests / PregnancyTransitionTests 공통 패턴
func d(_ s: String) -> Date { /* "yyyy-MM-dd" → Date */ }

// PregnancyTransitionTests 전용
func makeActivePregnancy(lmpDate:eddDate:fetusCount:status:) -> Pregnancy
```

### 4-4. 민감 영역 테스트 — 필수 표시

상실 관련 테스트는 반드시 주석으로 민감 영역임을 명시합니다.

```swift
/// status=.loss → .notActive  (상실 후 전환 차단 — 민감 영역)
func test_makeChild_loss_returnsNotActive() {
    // 유산/사산 이후 아이 승계를 차단하는 것은 사용자 데이터 무결성 및
    // 정서적 안전을 위한 핵심 정책이다. 이 테스트는 반드시 통과해야 한다.
    ...
}
```

### 4-5. TODO 주석 관리

현재 테스트 파일 상단에 `// TODO (리뷰어 관점)` 섹션으로 미작성 케이스가 명시되어 있습니다. 새 케이스 추가 시 TODO에서 제거하고 실제 테스트 메서드로 옮깁니다.

---

## 5. 미구현 케이스 — Phase 3 필수 추가

`team/debug/phase3-risk-audit.md`에서 도출된 우선순위 높은 미검증 항목들입니다.

### 5-1. AgeCalculator 경계값 (우선순위 높음)

| 케이스 | 파일 | 감사 ID |
|---|---|---|
| 시스템 시간대를 `America/Los_Angeles`로 오버라이드 후 임신 주수 계산 | `AgeCalculatorTests.swift` | A-1 |
| `LMP > 오늘` 입력 시 nil 반환 + UI 처리 확인 | `AgeCalculatorTests.swift` | A-3 |
| `EDD`가 과거 날짜일 때 `dDayToBirth` 음수 반환 확인 | `AgeCalculatorTests.swift` | A-3 |
| `birthDate = 2024-02-29` 기준 2025-02-28 vs 2025-03-01 월령 계산 | `AgeCalculatorTests.swift` | A-4 |

### 5-2. AppStore 원자성 (우선순위 높음)

| 케이스 | 감사 ID |
|---|---|
| 검증 실패 시 `pregnancies` 상태가 변경되지 않음 확인 | B-1 |
| 정상 전환 후 `EventBus.recordSaved` 이벤트 발행 확인 | B-1 |
| `fetusCount = 2`인 Pregnancy에서 `makeChild` 1회 호출 결과 확인 | B-3 |

### 5-3. NotificationService (우선순위 높음 — 민감 영역)

| 케이스 | 감사 ID |
|---|---|
| `pregnancyEndedInLoss` 발행 → mock scheduler의 `cancelPregnancyNotifications` 호출 확인 | C-1, H4 |
| 취소 후 `getPendingNotificationRequests`에 해당 prefix 알림이 없음 확인 | C-3 |

### 5-4. 상태머신 전이 규칙 (우선순위 높음)

| 케이스 | 감사 ID |
|---|---|
| `delivered → active`, `loss → delivered` 등 금지 전이 시도 시 차단 확인 | B-2 |
| `canTransitionTo` 메서드 추가 후 모든 전이 조합 표 기반 검증 | B-2 |

---

## 6. 향후 테스트 계획

### 6-1. 위젯(WidgetKit) 테스트

WidgetKit 타임라인 Provider가 `loss` 상태를 읽어 임신 콘텐츠를 숨기는지 검증합니다.

```
대상: WidgetKit Timeline Entry 생성 로직
검증: Pregnancy.status == .loss → 임신 위젯 콘텐츠 노출 없음
방법: Unit Test (WidgetKit Provider mock)
```

### 6-2. 통합(Integration) 테스트

CoreData + CloudKit 영속화 단계에서 추가합니다.

| 시나리오 | 검증 내용 |
|---|---|
| 전환 후 CoreData 재로드 | `context.save()` 후 fetch 시 `Child.pregnancyId == pregnancy.id` |
| 앱 강제 종료 후 재시작 | 불완전 전환 감지 (`status == .delivered && Child 없음`) 복구 플로우 |
| CloudKit 동기화 후 가족 기기 상태 | `pregnancyEndedInLoss` 전파 후 가족 기기 pending notification 비어있음 |

### 6-3. 스냅샷(Snapshot) 테스트

SwiftUI 뷰의 시각적 회귀를 방지합니다. 도입 라이브러리: `swift-snapshot-testing` (Point-Free).

| 대상 뷰 | 주요 상태 |
|---|---|
| 홈 화면 | baby 모드 / pregnancy 모드 / loss 모드(임신 카드 없음) |
| 기록 탭 | 타임라인 / 성장차트 / 예방접종 세그먼트 |
| 빠른기록 FAB | 닫힌 상태 / 펼쳐진 상태 / 임신 모드 액션 |
| 성장카드 공유 | `ImageRenderer` 출력 결과 픽셀 비교 |

> 스냅샷 테스트는 UI가 안정된 Phase 3 후반(화면 본구현 완료 후)에 도입합니다. 현재 골격 UI에 도입하면 잦은 업데이트로 유지 비용이 높아집니다.
