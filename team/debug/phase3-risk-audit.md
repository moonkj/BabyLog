# Phase 3 본구현 전 리스크/엣지케이스 정적 감사

> 작성: Teammate 2 — 디버거  
> 기준일: 2026-06-10  
> 대상: `App/Sources/` 파운데이션 코드 + SPEC.md 기능 1·2 + DESIGN_REVIEW.md + CLAUDE.md

---

## (A) 계산 로직 위험 — AgeCalculator

**파일:** `App/Sources/Core/AgeCalculator.swift`

### A-1. 시간대·DST 경계 오류

| 우선순위 | 높음 |
|----------|------|
| 현상 | `calendar.timeZone = .current`는 기기 시스템 시간대를 사용한다. 한국(KST, UTC+9)에서는 일반적으로 DST가 없어 위험이 낮으나, 해외 거주 한국인(미국·유럽)이 앱을 사용하거나 기기 시간대를 변경하면 `startOfDay`의 경계가 달라진다. LMP 또는 EDD를 저장할 때의 시간대와 계산 시의 시간대가 다를 경우 임신 주수가 ±1일 어긋난다. |
| 시나리오 1 | EDD를 KST에서 저장 → 미국 EST로 이동 후 계산: `startOfDay(for: edd)`가 9시간+5시간 = 14시간 이전 자정을 기준으로 변환돼 edd - 280일이 달라진다. |
| 시나리오 2 | DST 전환 날 자정에 `dateComponents([.day], from:to:)` 호출 시 역설적으로 총일수가 1일 누락되거나 중복될 수 있다(Calendar의 DST fold 처리). |
| 기대 동작 | 날짜를 저장할 때 `TimeZone.current`가 아닌 고정 기준(UTC 또는 KST)으로 정규화하고, 모든 `startOfDay` 계산은 동일 시간대 기준으로 수행해야 한다. |
| 검증 방법 | Unit Test: 시스템 시간대를 `America/Los_Angeles`로 오버라이드한 뒤 EDD = 2026-12-01(KST 기준)로 `pregnancyWeeks` 호출 → 기대 주수와 비교. |

### A-2. 임신 주수 EDD 우선 계산의 오류 시나리오

| 우선순위 | 높음 |
|----------|------|
| 현상 | EDD가 존재할 때 `conceptionBase = EDD - 280일`로 계산한다. 하지만 병원에서 에코 기반 EDD를 수정하는 경우(LMP 기반과 에코 기반 EDD 불일치 최대 ±2주) 두 값이 동시에 저장되면 어떤 EDD를 우선하는지 `Pregnancy` 모델에 필드가 하나뿐(`eddDate: Date?`)이라 외부에서 재계산 없이 덮어쓰면 주수가 갑자기 점프한다. |
| 시나리오 | 사용자가 LMP 기반 EDD 입력 후 에코 수정으로 EDD를 변경 → 주수가 +2주 또는 -2주 이동 → 이전 주차 알림(산전검사 일정)이 이미 전송됐거나, 새 일정과 충돌. |
| 기대 동작 | EDD 변경 시 이력을 남기거나(eddHistory), 변경 이유를 기록해 알림 재계산을 트리거한다. |
| 검증 방법 | `eddDate` 변경 전후 `pregnancyWeeks` 결과 비교 + 산전검사 알림 재스케줄 로직 유무 확인. |

### A-3. 경계 케이스 — 미래/과거 오류 입력

| 우선순위 | 높음 |
|----------|------|

| 케이스 | 현재 코드 동작 | 기대 동작 |
|--------|----------------|------------|
| LMP > 오늘 | `totalDays < 0` → `return nil`로 nil 반환. UI에서 nil 처리를 안 하면 크래시 또는 "-주차" 표시 가능. | UI 진입 전 입력 검증으로 차단. nil 수신 시 명시적 오류 메시지. |
| EDD가 과거 (이미 지난 날짜) | `dDayToBirth` 반환 값이 음수. UI가 "D-(-3)" 출력 여부 확인 필요. | "예정일이 지났습니다. 출산 여부를 확인해주세요." 전환 유도 메시지. |
| birthDate > 오늘 (미래 출생일) | `dPlusDays`는 음수 + 1 = 0 또는 음수. `childAgeMonths`에서 `components.month`가 음수 가능. | 미래 날짜 입력 자체를 DatePicker에서 차단. |
| LMP와 EDD 모두 nil | `pregnancyWeeks` → nil 반환. | 온보딩 단계에서 둘 중 하나를 필수 입력으로 강제. |

| 검증 방법 | XCTest로 각 경계값(LMP = tomorrow, EDD = yesterday, birthDate = tomorrow) 입력 후 반환값 및 UI 렌더링 확인. |

### A-4. 윤년 처리

| 우선순위 | 중간 |
|----------|------|
| 현상 | `calendar.dateComponents([.month, .day], from: birth, to: today)`는 Calendar가 윤년을 처리하므로 2월 29일 생일(2024-02-29)인 아이의 월령 계산이 평년에는 2월 28일 또는 3월 1일 기준으로 처리된다. Apple Calendar API는 대체로 2월 28일을 기준으로 하나 명시적으로 문서화되지 않음. |
| 시나리오 | 2024-02-29 출생 아이가 2025-02-28에 12개월인지, 2025-03-01에 12개월인지 앱과 부모 인지가 다를 수 있음. |
| 기대 동작 | 한국 아동 행정상 관례(2월 28일 기준)를 따르고, 이를 코드 주석으로 명시. |
| 검증 방법 | birthDate = 2024-02-29, asOf = 2025-02-28과 2025-03-01에 대해 `childAgeMonths` 반환값 확인. |

### A-5. Calendar 인스턴스 공유 스레드 안전성

| 우선순위 | 중간 |
|----------|------|
| 현상 | `AgeCalculator.calendar`가 `static var`로 선언되어 있고 `.timeZone` 프로퍼티가 mutable이다. 멀티스레드 환경(CloudKit 동기화 콜백, WidgetKit 백그라운드 타임라인)에서 동시 접근 시 레이스 컨디션 가능. |
| 기대 동작 | `static let`으로 변경하거나, 계산 시마다 로컬 Calendar 인스턴스를 생성한다. |
| 검증 방법 | Thread Sanitizer 활성화 후 Background CloudKit fetch와 AgeCalculator 동시 호출 시나리오 실행. |

---

## (B) Pregnancy→Child 전환(R1) — PregnancyTransition

**파일:** `App/Sources/Data/PregnancyTransition.swift`, `App/Sources/Data/Models.swift`

### B-1. 원자성 부재 — "호출측 책임" 명시 없는 실제 구현

| 우선순위 | 높음 |
|----------|------|
| 현상 | `PregnancyTransition.makeChild(from:input:)`은 Child 객체를 생성해 반환하지만 "원자성은 호출측 책임"이라고 주석에만 명시되어 있다. 실제 CoreData 컨텍스트에서 ① `Pregnancy.status = .delivered` 저장 ② `Child` 삽입 ③ 기존 기록(MaternalRecord, PrenatalCheckup 등)의 childId 연결 ④ `context.save()` 중 어느 단계에서 앱이 종료되거나 CloudKit 동기화가 끊기면 불완전한 상태로 남는다. |
| 부분 전환 시나리오 | ① Pregnancy.status = .delivered 저장 성공 → ② Child 삽입 전 앱 강제 종료 → 재시작 시 Pregnancy는 delivered이나 Child가 없음 → 홈 화면 데이터 없음, 알림 타깃 없음. |
| 시나리오 2 | CloudKit 동기화 중 Child는 로컬에 있으나 아직 서버에 미업로드 → 가족 구성원 기기에서 Pregnancy는 delivered이나 Child 없음 → 가족 기기에서 빈 화면 표시. |
| 기대 동작 | CoreData NSBatchUpdateRequest + 단일 `context.save()` 호출로 Pregnancy 상태 변경과 Child 삽입을 동일 트랜잭션에서 수행. 재시작 시 `(status == .delivered && pregnancyId를 가진 Child가 없음)` 조건 감지 → 복구 플로우 또는 재전환 요청. |
| 롤백 전략 가설 | 전환 전 Pregnancy 상태를 별도 `pendingTransition` 필드로 표시 → Child 생성 완료 후 `delivered`로 확정. 실패 시 `pendingTransition` 리셋. |
| 검증 방법 | Xcode Memory Debugger로 전환 중 강제 종료(SIGKILL) 후 재시작 → CoreData 상태 점검. |

### B-2. 상태머신 불변식 검증 부족

| 우선순위 | 높음 |
|----------|------|
| 현상 | `PregnancyStatus` enum은 `active / delivered / loss / paused` 4가지이나, 전이 규칙이 코드로 강제되지 않는다. |

| 허용되어야 할 전이 | 금지되어야 할 전이 |
|-------------------|-------------------|
| active → delivered | delivered → active |
| active → loss | loss → delivered |
| active → paused | delivered → loss |
| paused → active | loss → paused |
| paused → loss | — |

현재 `makeChild`는 `status != .active`면 `.notActive`를 반환하지만, 호출측에서 `.loss` 상태 Pregnancy에 `makeChild`를 재호출하면 에러만 반환될 뿐 DB에 잘못된 상태가 기록되는 것은 막지 못한다. UI에서 이미 loss 상태인 경우에도 "출산했어요" 버튼을 노출할 가능성이 있다.

| 기대 동작 | `PregnancyStatus`에 `canTransitionTo(_ next: PregnancyStatus) -> Bool` 메서드를 추가해 전이 규칙을 단일 소스로 관리. UI는 이 메서드로 버튼 활성화 여부 결정. |
| 검증 방법 | 각 상태에서 모든 전이 시도의 결과를 XCTest로 표 기반 검증. |

### B-3. 다태아(쌍둥이) 전환 미검토

| 우선순위 | 중간 |
|----------|------|
| 현상 | `Pregnancy.fetusCount`가 2 이상일 때 `makeChild`는 Child를 1개만 생성한다. 쌍둥이의 경우 Child 2개를 생성해야 하며 각각 `pregnancyId`를 공유할지 별도 Pregnancy를 가질지 정책이 없다. |
| 시나리오 | 쌍둥이 Pregnancy에서 첫째만 전환 완료, 둘째 전환 중 앱 종료 → Pregnancy는 delivered이나 Child가 1개만 존재. |
| 기대 동작 | fetusCount > 1일 때 Child 생성 UI를 fetusCount회 반복하거나, 배치 전환 로직을 구현. |
| 검증 방법 | fetusCount = 2인 Pregnancy에서 makeChild 호출 후 Child 수 확인. |

### B-4. 임신 기록 연속성 단절 위험

| 우선순위 | 높음 |
|----------|------|
| 현상 | `MaternalRecord`, `FetalMovement`, `PrenatalCheckup` 모델은 `SPEC.md`에 정의되어 있으나 `Models.swift`에 없다(Phase 3 미구현). 전환 시 이 기록들이 Child의 타임라인에 연결되는 메커니즘이 없다. CLAUDE.md는 "태아 시절부터 성장까지 끊김 없는 하나의 여정"을 핵심 가치로 명시하고 있어 구현 누락 시 핵심 UVP가 사라진다. |
| 기대 동작 | MaternalRecord.pregnancyId → Child.pregnancyId 체인으로 타임라인 연결. 전환 후 기록탭의 "태아 시절" 섹션에 임신 기록이 자동으로 노출돼야 한다. |
| 검증 방법 | CoreData fetch request: `NSPredicate(format: "pregnancyId == %@", child.pregnancyId as CVarArg)` 결과 확인. |

---

## (C) 민감 영역 — 상실·알림 제어

### C-1. '기록 멈춤' 트리거 — 30일 자동 감지 정책 미구현

| 우선순위 | 높음 |
|----------|------|
| 현상 | CLAUDE.md와 SPEC.md B.5는 "오래 미접속 시 권유 알림을 자동 완화"한다고 명시하나, 30일의 기준이 어디에도 코드로 구현되지 않았다. EventBus에 `pregnancyEndedInLoss` 이벤트가 있으나 이 이벤트를 수신해 알림을 중단하는 구독자가 존재하지 않는다. |
| 위험 | 상실한 사용자가 "기록 멈춤"을 직접 설정하지 않으면 30일 이후에도 "○○이 몇 주차예요! 태동을 기록해보세요" 알림이 계속 발송된다. 이것은 CLAUDE.md 민감영역 최고원칙 위반. |
| 30일 기준 명확화 필요 사항 | ① 30일의 의미: 마지막 앱 실행 후 30일? 마지막 기록 후 30일? ② 자동 완화 = 알림 주기 축소? 완전 중단? ③ 재활성화 조건은? |
| 기대 동작 | ① `pregnancyEndedInLoss` 이벤트 구독 시 즉시 해당 Pregnancy의 모든 예약 알림 취소(UNUserNotificationCenter.removePendingNotificationRequests). ② 미접속 감지는 Background App Refresh 또는 다음 앱 실행 시 UserDefaults의 lastActiveDate를 비교해 30일 초과 시 권유 알림 비활성화. |
| 검증 방법 | `pregnancyEndedInLoss` publish 후 UNUserNotificationCenter.current().pendingNotificationRequests가 비어있는지 XCTest 확인. |

### C-2. 가족 기기 알림 선도달 위험

| 우선순위 | 높음 |
|----------|------|
| 현상 | SPEC.md 10.3은 "부부가 함께 쓸 때 동일 알림이 양쪽에 중복 발송되지 않도록 역할 분담"을 명시한다. 상실 이후 상실 당사자(산모)가 앱에서 "기록 멈춤"을 설정하기 전에 CloudKit 동기화를 통해 배우자 기기에도 임신 정보가 공유되어 있다면, 배우자 기기에서 "○○주차 산전검사 일정이 곧 다가와요" 알림이 먼저 도달할 수 있다. |
| 시나리오 | 산모가 상실을 경험 → 아직 앱을 열지 않아 status 미변경 → 배우자 기기에서 자동으로 임신 알림 수신 → 배우자가 산모에게 알림 내용 언급 → 이차 상처. |
| 기대 동작 | 알림은 설정한 당사자 기기에서만 발송(CloudKit record의 알림 발신 기기 태그 관리). 가족 알림 라우팅 설계 시 상실 상태 전파(CloudKit notification)를 가장 먼저 처리하고 나머지 알림을 일시 중단. |
| 검증 방법 | 시뮬레이터 2대(CloudKit 테스트 환경)에서 상실 이벤트 처리 전후 각 기기의 pending notification 목록 비교. |

### C-3. 상실 후 즉시 알림 차단 검증 포인트

| 우선순위 | 높음 |
|----------|------|

CLAUDE.md는 "상실 시 모든 주차 알림·태아 가이드·권유 알림을 **즉시** 중단"을 요구한다. 검증해야 할 포인트:

1. **로컬 푸시(UNUserNotificationCenter)**: `status = .loss` 변경 직후 `removePendingNotificationRequests(withIdentifiers:)`가 해당 pregnancyId 관련 모든 알림 식별자를 제거하는가?
2. **서버 푸시(향후 Supabase Functions)**: 서버에서 예약된 푸시가 있을 경우 서버 측 취소 API 호출이 포함되어 있는가?
3. **홈 화면 우선순위 카드**: 상실 후 홈에 "○○주차 가이드" 카드가 잔류하지 않는가?
4. **위젯(WidgetKit)**: 위젯 타임라인이 갱신될 때 loss 상태를 읽어 임신 관련 콘텐츠를 숨기는가?
5. **알림 발송 후 loss 변경**: 알림이 이미 발송된 후 loss 변경 시 발송된 알림을 소급 처리하는 메커니즘 불필요하나, 발송 전 큐에서는 반드시 제거.

| 검증 방법 | EventBus에서 `pregnancyEndedInLoss` 이벤트 발행 후 위 5개 포인트를 순서대로 체크리스트 점검. |

---

## (D) 파운데이션 코드 점검

### D-1. LiquidButton repeatForever 애니메이션 — 메모리·배터리

| 우선순위 | 높음 |
|----------|------|
| 파일 | `App/Sources/Components/LiquidButton.swift` 65번째 줄 |
| 현상 | `band` 뷰의 애니메이션이 `.timingCurve(..., duration: 4.6).repeatForever(autoreverses: false)`로 설정되어 있고, `onAppear { flow = true }`로 즉시 시작된다. LiquidButton이 화면에 여러 개 존재하면(홈의 "접종 예약하기" + 동네탭의 "전화하기" + 가계부탭의 "신청 방법 보기" 등) 각 버튼마다 `GeometryReader` + `LinearGradient` + `blur(radius: 3)` + 무한 애니메이션이 동시 실행된다. |
| 위험 | ① Core Animation 레이어가 탭별로 쌓이고, iOS의 IndexedStack(탭 상태 보존) 사용 시 백그라운드 탭에서도 애니메이션이 지속될 수 있다. ② 저전력 기기(iPhone SE 1세대 같은 구형 기기는 iOS 16+ 지원 범위 밖이나, iPhone SE 2세대 등 최소 사양 기기)에서 배터리 드레인 가중. ③ 백그라운드 진입 시 애니메이션 중단 처리가 없음. |
| 기대 동작 | `onDisappear { flow = false }`를 추가해 뷰가 사라질 때 애니메이션을 중단. 또는 `@Environment(\.scenePhase)`를 감지해 background 진입 시 중단. |
| 검증 방법 | Instruments > Energy Log에서 LiquidButton 3개가 동시에 표시되는 화면에서 5분 대기 → CPU/GPU 사용률 측정. 탭 전환 후 백그라운드 탭의 Core Animation 레이어 상태 확인(Instruments > Core Animation). |

### D-2. reduce-motion 처리 적정성

| 우선순위 | 중간 |
|----------|------|
| 현상 | `band` 뷰는 `if !reduceMotion { band }` 조건으로 비활성화된다. 그러나 `meniscus`(RadialGradient + LinearGradient 오버레이)는 reduce-motion에 무관하게 항상 렌더된다. 또한 `LiquidPressStyle`의 `scaleEffect` 애니메이션(`.easeOut(duration: 0.12)`)도 reduce-motion을 별도 체크하지 않는다. |
| 위험 | WCAG 2.1 기준에서 "움직임으로 인한 불편함이 있는 사용자"는 모든 애니메이션을 중단할 권리가 있다. 스케일 애니메이션도 vestibular disorder를 가진 사용자에게 영향을 줄 수 있다. |
| 기대 동작 | `LiquidPressStyle`에 `@Environment(\.accessibilityReduceMotion)` 체크를 추가해 reduce-motion 시 스케일 애니메이션을 `animation: nil`로 처리. |
| 검증 방법 | 시뮬레이터에서 Accessibility > Reduce Motion 활성화 후 LiquidButton 탭 → 스케일 변화 여부 확인. |

### D-3. AppColors 다크 모드 대비(WCAG AA) 의심 항목

| 우선순위 | 높음 |
|----------|------|
| 파일 | `App/Sources/DesignSystem/AppColors.swift` |

WCAG AA 기준: 일반 텍스트 4.5:1, 대형 텍스트(18pt bold 이상) 3:1.

| 조합 | 라이트 대비비(추정) | 다크 대비비(추정) | 위험도 |
|------|---------------------|-------------------|----|
| `ink3`(#A89D8C) on `canvas`(#F4EFE6) | 약 2.8:1 | — | **AA 미달** (라이트) |
| `ink3`(#8A8175) on `surface`(#2A2A2D) 다크 | — | 약 3.2:1 | 소형 텍스트 AA 미달 |
| `ink2`(#6B6256) on `canvas`(#F4EFE6) | 약 4.4:1 | — | 경계값, 소형 텍스트 미달 우려 |
| `primary`(#4E8268) on `canvas`(#F4EFE6) | 약 3.3:1 | — | 소형 텍스트 AA 미달 (탭 아이콘 `.tint` 적용 시) |
| `ink3`(다크 #8A8175) on `surface2`(다크 #222226) | — | 약 2.7:1 | **AA 미달** |
| BadgeTone.grey ink(#877E6B) on grey bg(#F1EFE8) | 약 3.1:1 | — | 소형 Bold 경계 |

> ※ 대비비는 WCAG 공식(상대 휘도 기반)으로 hex에서 추정. 정확한 수치는 별도 도구(Colour Contrast Analyser) 검증 필요.

`ink3`와 `ink2`는 하위 정보(부제목, 캡션, 안내 텍스트)에 광범위하게 사용된다. `AppFont.caption`(13pt medium)은 WCAG에서 소형 텍스트로 분류되어 4.5:1이 요구되는데 라이트 모드에서 미달 가능성이 있다.

| 기대 동작 | Asset Catalog named color로 이관 시(DESIGN.md §2.4 권고) 각 색상 조합을 Accessibility Inspector로 검증. 미달 항목은 ink3 조합만 secondary 역할로 제한하고 핵심 정보는 ink 또는 ink2로만 표시. |
| 검증 방법 | Xcode Accessibility Inspector > Color Contrast 기능으로 실기기 UI 픽셀 단위 대비비 측정. |

### D-4. FAB 히트 타깃 및 접근성 라벨

| 우선순위 | 중간 |
|----------|------|
| 파일 | `App/Sources/Shell/QuickRecordFAB.swift` |
| 현상 1 — 히트 타깃 | 메인 FAB 버튼의 프레임은 `width: 58, height: 58`이다. iOS HIG는 최소 44×44pt를 권장하므로 이 자체는 충족된다. 그러나 스피드다이얼이 열렸을 때 하위 액션 버튼들의 아이콘 영역은 `width: 44, height: 44`(Circle)로 경계값이고, 레이블 Capsule과 아이콘 Circle이 별개 뷰로 분리되어 있어 실제 탭 가능 영역이 HStack 전체가 아닌 각 요소별로 나뉜다. 두 요소 사이 gap(9pt)은 탭 불가 영역. |
| 현상 2 — 접근성 라벨 | 메인 FAB에 `.accessibilityLabel("빠른 기록")`이 있어 VoiceOver 대응이 일부 존재한다. 그러나 열린 상태(`open = true`)와 닫힌 상태에서 VoiceOver가 동일하게 "빠른 기록"으로 읽는다. 상태 정보(`expanded/collapsed`)가 없고, 하위 액션 버튼들에도 accessibilityLabel이 없다(Text 레이블은 visually accessible하나 VoiceOver 포커스 순서 미지정). |
| 현상 3 — 임신 모드 전환 | `MainTabView`의 `mode: AppMode` 상태가 하드코딩 `.baby`로 초기화되어 있고, 전환 로직이 없다. `QuickRecordFAB(mode: mode)`에 pregnancy 모드의 액션이 있으나 실제로는 항상 baby 모드 액션이 표시된다. |
| 기대 동작 | ① HStack 전체를 단일 Button으로 래핑해 히트 타깃 통합. ② `.accessibilityLabel`에 상태 포함: open 시 "빠른 기록 메뉴 닫기", closed 시 "빠른 기록 메뉴 열기". ③ 하위 액션에 각각 `.accessibilityLabel(a.label)` 명시. ④ mode 전환 로직 연결. |
| 검증 방법 | VoiceOver 활성화 후 FAB 탭 → 읽히는 텍스트 확인. Accessibility Inspector > Hit Testing으로 탭 영역 시각화. |

---

## (E) 가설 검증 후보

### [가설 H1] 다중 LiquidButton의 repeatForever 애니메이션이 탭 전환 후에도 지속되어 배터리를 소모한다
- **현상**: `MainTabView`가 IndexedStack 방식을 사용해 탭 상태를 보존하면, 백그라운드 탭의 LiquidButton도 Core Animation 레이어를 유지한다. `onDisappear`가 없으므로 `flow = true` 상태가 유지되고 animation이 실행 중인 레이어가 GPU를 점유한다.
- **검증 방법**: Instruments > Energy Log에서 탭 전환 후 이전 탭의 GPU/CPU 사용률 프로파일링. SwiftUI `body` 재호출 여부는 `.onChange(of:)` 로그로 확인.
- **기대**: 탭 전환 후 백그라운드 탭의 repeatForever 애니메이션이 지속됨을 확인 → `onDisappear { flow = false }` 패치로 해결.

---

### [가설 H2] LMP 없이 EDD만 입력한 Pregnancy에서 birthDateBeforeLMP 오류가 발생하지 않으나 다른 경계 오류가 발생한다
- **현상**: `PregnancyTransition.makeChild`에서 LMP가 nil이면 `birthDateBeforeLMP` 체크를 건너뛴다(line 43: `if let lmp = pregnancy.lmpDate`). EDD만 입력한 경우 birthDate 검증 기준이 없어 EDD 이후 100일 뒤를 birthDate로 입력해도 성공한다. 이는 실제로는 불가능한 날짜지만 앱은 수용한다.
- **검증 방법**: EDD = 2026-12-01, lmpDate = nil인 Pregnancy에서 birthDate = 2027-05-01(EDD + 5개월)로 makeChild 호출 → 결과 확인.
- **기대**: 현재 코드는 성공을 반환. EDD 기반으로 `birthDate < (eddDate - 보정 범위)` 검증을 추가해야 한다는 가설 확인.

---

### [가설 H3] AppColors의 ink3(라이트 #A89D8C on canvas #F4EFE6) 조합이 WCAG AA 4.5:1 기준을 실제로 미달한다
- **현상**: 추정 대비비 약 2.8:1. `AppFont.caption`(13pt medium) 텍스트에 ink3가 광범위하게 사용된다(BLSectionHead의 eyebrow, 부제목 전반).
- **검증 방법**: Colour Contrast Analyser 또는 WebAIM Contrast Checker에 #A89D8C(fg) / #F4EFE6(bg) 입력 → 정확한 대비비 산출. Xcode Accessibility Inspector로 실기기 픽셀 추출 후 재확인.
- **기대**: AA 미달 확인 → 카피 역할의 ink3를 캡션에서 제거하거나 background를 밝게 조정.

---

### [가설 H4] pregnancyEndedInLoss 이벤트를 publish해도 알림이 즉시 취소되지 않는다
- **현상**: `EventBus`에 `pregnancyEndedInLoss` 이벤트가 정의되어 있으나 이를 구독하는 코드가 현재 codebase에 존재하지 않는다. 이벤트 발행 자체가 알림 취소로 이어지는 연결 고리가 없다.
- **검증 방법**: EventBus.shared.publish(.pregnancyEndedInLoss(pregnancyId: testId)) 호출 후 UNUserNotificationCenter.current().getPendingNotificationRequests { requests in print(requests) } 로 pending 알림 목록 확인.
- **기대**: pending 알림이 그대로 남아있음을 확인 → 이벤트 구독자(NotificationScheduler 등)가 Phase 3에서 반드시 구현되어야 함을 증거로 제시.

---

### [가설 H5] 탭 선택 전환 시 QuickRecordFAB의 transition 애니메이션이 LiquidPressStyle과 충돌해 시각적 깜빡임이 발생한다
- **현상**: `MainTabView`에서 FAB는 `if tab == .home || tab == .record || tab == .dongne` 조건으로 `.scale.combined(with: .opacity)` 전환을 사용한다. budget이나 profile 탭 진입 시 FAB가 사라지고 home 탭 복귀 시 다시 나타난다. 이때 LiquidButton의 `onAppear { flow = true }` 가 재실행되어 빛 띠 애니메이션이 처음부터 재시작된다. 여러 탭을 빠르게 전환하면 flow 상태 변경과 transition이 겹친다.
- **검증 방법**: 홈 → 가계부 → 홈 → 가계부를 빠르게(0.2초 간격) 5회 반복 → FAB 애니메이션 상태 관찰.
- **기대**: 빠른 전환 시 band 애니메이션이 중간 상태에서 재시작되거나 transition과 겹쳐 깜빡임 발생. `flow` 상태를 `@State` 대신 전환 완료 후에만 초기화하는 방식으로 개선 가능.

---

## 우선순위 요약

| ID | 항목 | 우선순위 | 검증 방법 |
|----|------|----------|-----------|
| A-1 | 시간대·DST 경계 오류 | **높음** | Unit Test (시간대 오버라이드) |
| A-2 | EDD 수정 시 주수 점프 | **높음** | 전후 비교 테스트 |
| A-3 | 경계 입력(LMP>오늘, EDD 과거, 미래 출생일) | **높음** | XCTest 각 케이스 |
| A-4 | 윤년 2월 29일 월령 계산 | 중간 | 특정 날짜 XCTest |
| A-5 | Calendar static var 스레드 안전성 | 중간 | Thread Sanitizer |
| B-1 | 전환 원자성 부재 + 롤백 없음 | **높음** | 강제 종료 후 CoreData 상태 점검 |
| B-2 | 상태머신 전이 규칙 미강제 | **높음** | 표 기반 XCTest |
| B-3 | 다태아 전환 미처리 | 중간 | fetusCount > 1 시나리오 테스트 |
| B-4 | 임신 기록 → Child 타임라인 연결 부재 | **높음** | CoreData fetch 확인 |
| C-1 | 상실 후 30일 미접속 자동 완화 미구현 | **높음** | EventBus 구독자 존재 여부 코드 검색 |
| C-2 | 가족 기기 알림 선도달 위험 | **높음** | 시뮬레이터 2대 CloudKit 테스트 |
| C-3 | 상실 후 즉시 알림 차단 5개 포인트 | **높음** | 체크리스트 코드 리뷰 + 테스트 |
| D-1 | LiquidButton repeatForever 배터리 | **높음** | Instruments Energy Log |
| D-2 | reduce-motion 스케일 애니메이션 미처리 | 중간 | 시뮬레이터 Reduce Motion 테스트 |
| D-3 | AppColors 다크 WCAG AA 미달 의심 | **높음** | Accessibility Inspector |
| D-4 | FAB 히트 타깃 / VoiceOver 라벨 | 중간 | VoiceOver 테스트 + Hit Testing |

---

## 최고위험 3개 즉시 검증 권고 (200단어 이내 한국어 요약)

**최고위험 1 — 상실 후 알림 즉시 차단 미구현 (C-1, C-2, C-3)**  
`EventBus.pregnancyEndedInLoss`를 수신하는 구독자가 없어, 상실 사용자에게 임신 주차 알림이 계속 발송된다. CLAUDE.md의 절대 원칙(민감 영역) 위반이며 브랜드 치명타. Phase 3 알림 스케줄러 구현 전 반드시 이벤트→알림 취소 연결 구조를 설계해야 한다.

**최고위험 2 — Pregnancy→Child 전환 원자성 없음 (B-1, B-2)**  
전환 중 앱 종료 시 Pregnancy는 delivered이나 Child가 없는 고아 상태가 발생한다. CoreData 단일 컨텍스트 트랜잭션으로 묶고, 재시작 시 불완전 전환을 감지·복구하는 로직이 Phase 3에서 가장 먼저 설계되어야 한다.

**최고위험 3 — AgeCalculator 시간대 + 경계값 오류 (A-1, A-3)**  
해외 거주 사용자의 시간대 변경이나 LMP > 오늘 입력 시 주수/월령이 오작동한다. 저장 시 UTC 정규화 + UI 진입 전 입력 검증을 Phase 3 데이터 레이어 구축 시 병행 적용해야 한다.

---

> 본 감사는 정적 코드 분석이며 빌드·실행 없이 작성되었다. 실제 수치(대비비 등)는 전용 도구로 재검증 필요.
