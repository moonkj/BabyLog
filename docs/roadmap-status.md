# BabyLog 로드맵 & 진행 현황

> 작성일: 2026-06-10  
> 입력: `SPEC.md`, `CLAUDE.md`, `team/DESIGN_REVIEW.md`, `team/TEAM.md`, `team/debug/phase3-risk-audit.md`, `docs/testing.md`, `docs/architecture.md`, `docs/data-and-persistence.md`, `App/Sources/`

---

## 1. 전체 Phase 진행 요약

| Phase | 명칭 | 상태 | 주요 산출물 |
|---|---|---|---|
| **Phase 0** | 기반 설계 & 결정 | ✅ 완료 | SPEC.md v0.2 (30라운드 토론), CLAUDE.md 절대 원칙, 기술 스택 확정, Flutter → SwiftUI 전환 결정 |
| **Phase 1** | 디자인 시스템 구현 | ✅ 완료 | 토큰 Swift 이식, LiquidGlass, LiquidButton, BLComponents 빌드 성공 |
| **Phase 2** | 셸 & 파운데이션 구현 | ✅ 완료 | MainTabView(5탭), QuickRecordFAB(스피드다이얼), 이벤트 버스, 도메인 모델, 출산 전환 로직, 알림 서비스, 단위 테스트 43개 |
| **Phase 3** | 화면 본구현 (진행 예정) | 🔲 예정 | 각 탭 화면 본구현, CoreData+CloudKit 영속화, 외부 API 연동, 접근성 완성 |

---

## 2. Phase별 상세 현황

### Phase 0 — 기반 설계 & 결정 ✅

**기간**: 프로젝트 초기  
**산출물**:

| 산출물 | 내용 |
|---|---|
| `SPEC.md` v0.2 | 14개 기능 풀스코프 + 30라운드 페르소나·전문가 토론 반영. 온보딩·홈·알림·AI·접근성·신뢰안전·데이터·프라이버시 섹션 신설. |
| `CLAUDE.md` | 절대 원칙 8개, 민감 영역 정책, 아키텍처 규칙, UX 원칙 확정. |
| 기술 스택 확정 | SwiftUI (iOS 26+ Liquid Glass 네이티브), CoreData+CloudKit, Supabase(v2~), StoreKit 2, Swift Charts, WidgetKit, ImageRenderer. |
| Flutter → SwiftUI 전환 | 핸드오프 README가 Flutter 기준이었으나 iOS 26 Liquid Glass 네이티브 지원 + SPEC 원본 스택 일치로 SwiftUI 최종 확정. |
| IA 확정 | 5탭 구조(홈·기록·동네·가계부·내정보) + 우하단 FAB 스피드다이얼. 중앙 탭바 FAB 미채택. |
| 핸드오프 자산 분류 | `design/handoff/design_files/app/*.jsx` 13개: 픽셀·카피·레이아웃 참조 소스로만 사용(Flutter 코드 복붙 금지). |

---

### Phase 1 — 디자인 시스템 구현 ✅

**산출물**: `App/Sources/DesignSystem/` + `App/Sources/Components/`

| 파일 | 내용 | 상태 |
|---|---|---|
| `AppColors.swift` | 색상 토큰 라이트/다크 적응형 (UIColor dynamic provider). 뱃지 7색 팔레트(`BadgeTone` enum). 응급·임신 고정 색상. | ✅ |
| `AppTypography.swift` | 9단계 타이포 스케일(`AppFont` enum). tabular figures 지원. Pretendard Variable 번들은 TODO. | ✅ (Pretendard 미완) |
| `AppMetrics.swift` | 간격(Spacing 9단계), 라운드(Radius 6단계), 그림자(BLShadowKind 4종, 따뜻한 톤). | ✅ |
| `LiquidGlass.swift` | iOS 26 `.glassEffect` 네이티브 + iOS 25 이하 `.ultraThinMaterial` 자동 폴백. | ✅ |
| `LiquidButton.swift` | 시그니처 CTA. 광택 메니스커스 + 4.6s 흐르는 빛 띠 루프. `@Environment(\.accessibilityReduceMotion)` 자동 대응. | ✅ |
| `BLComponents.swift` | `BLCard` / `BLBadge` / `BLChip` / `BLSectionHead` / `PhotoPlaceholder`. | ✅ |

**디자인 시스템 원칙 구현 확인**:
- 색 + 아이콘 + 레이블 3중 인코딩 패턴 확립 (색만으로 정보 전달 금지).
- Dynamic Type: `AppFont` 전체 `Font.system(size:weight:)` 기반.
- VoiceOver: 컴포넌트 수준 `.accessibilityLabel` 가이드 문서화 완료.

---

### Phase 2 — 셸 & 파운데이션 구현 ✅

**산출물**: `App/Sources/Shell/` + `App/Sources/Core/` + `App/Sources/Data/` + `App/Sources/Notifications/`

#### 2-1. 네비게이션 셸

| 파일 | 내용 | 상태 |
|---|---|---|
| `MainTabView.swift` | `AppTab` enum 5탭. `AppMode` enum (`.baby / .pregnancy`). iOS 26 시스템 Liquid Glass 탭바 자동 적용. | ✅ |
| `QuickRecordFAB.swift` | 우하단 스피드다이얼 FAB. 45° 회전 애니메이션. 모드별 액션 분기. 홈·기록·동네에서만 노출. | ✅ |
| `Tabs.swift` | 5개 탭 골격 뷰. 디자인 시스템 적용. 화면 본구현은 Phase 3. | ✅ (골격) |

#### 2-2. 파운데이션 레이어

| 파일 | 내용 | 상태 |
|---|---|---|
| `EventBus.swift` | Combine `PassthroughSubject<AppEvent, Never>` 싱글톤. `AppEvent`: `milestoneAchieved / recordSaved / pregnancyEndedInLoss`. | ✅ |
| `AgeCalculator.swift` | 임신 주수(`pregnancyWeeks`), 아이 월령(`childAgeMonths`), D+일(`dPlusDays`), 출산 D-day(`dDayToBirth`). EDD 우선·LMP 폴백. | ✅ |
| `Models.swift` | `Pregnancy / Child / GrowthRecord / DiaryEntry / VaccineRecord`. `Identifiable·Codable·Equatable` 준수. `PregnancyStatus` enum 4상태. | ✅ |
| `PregnancyTransition.swift` | 순수 함수 `makeChild(from:input:)`. 3단계 검증(status·이름·출생일). `Result<Child, BirthTransitionError>`. | ✅ |
| `AppStore.swift` | 인메모리 스토어. `commitBirthTransition`: 원자적 상태 커밋(검증 실패 시 양쪽 배열 무변경). EventBus 발행. | ✅ (인메모리만) |

#### 2-3. 알림 레이어

| 파일 | 내용 | 상태 |
|---|---|---|
| `NotificationService.swift` | `NotificationScheduling` 프로토콜 (mock 교체 가능). EventBus `.pregnancyEndedInLoss` 구독 → 즉시 알림 취소. 알림 식별자 prefix: `"preg-<pregnancyId.uuidString>"`. | ✅ |

#### 2-4. 기록 화면 골격

| 파일 | 내용 | 상태 |
|---|---|---|
| `RecordScreen.swift` | 세그먼트(타임라인/성장차트/예방접종) 골격. 디자인 시스템 적용. | ✅ (골격) |

---

## 3. 테스트 현황

**총 작성 테스트 케이스: 43개**  
(AgeCalculatorTests 15 + PregnancyTransitionTests 12 + NotificationServiceTests 6 + AppStoreTransitionTests 10)

### 3-1. AgeCalculator — 15개

| 분류 | 케이스 수 | 검증 내용 |
|---|---|---|
| 임신 주수 계산 | 5 | LMP·EDD 우선순위, 양쪽 nil, EDD only, 임신 당일 (0, 0) |
| 아이 월령 계산 | 3 | 14개월 5일, 당일 (0, 0), 정확히 1개월 |
| D+일 계산 | 4 | 출생 당일 D+1, 다음날 D+2, 백일(D+100), 50일 |
| 출산 D-day | 3 | 7일 전, 2일 후, 당일 0 |

### 3-2. PregnancyTransition — 12개

| 분류 | 케이스 수 | 검증 내용 |
|---|---|---|
| 성공 케이스 | 2 | 정상 입력 성공·pregnancyId 승계, gender nil 허용 |
| NotActive 에러 | 3 | .delivered / .loss / .paused 상태에서 전환 차단 |
| EmptyName 에러 | 3 | 공백·빈 문자열·탭개행 → `.emptyName` |
| 날짜 에러 | 3 | birthDate < lmpDate, 경계값, lmpDate nil 시 에러 미발생 |
| 추가 계약 | 1 | 연속 호출 시 고유 UUID 보장 |

> **민감 영역 필수 테스트**: `test_makeChild_loss_returnsNotActive` — 상실 후 아이 승계 차단. 이 테스트는 반드시 통과해야 함.

### 3-3. NotificationService — 6개

| 분류 | 케이스 수 | 검증 내용 |
|---|---|---|
| 알림 취소 흐름 | 6 | MockNotificationScheduler 주입 → EventBus `.pregnancyEndedInLoss` 발행 → cancelPregnancyNotifications 호출 확인 등 |

### 3-4. AppStoreTransition — 10개

| 분류 | 케이스 수 | 검증 내용 |
|---|---|---|
| 원자성 검증 | 10 | 존재하지 않는 ID / .delivered 상태 / 빈 이름 → 양쪽 배열 무변경. 정상 입력 → Child 추가 + EventBus 발행. |

---

## 4. 완료된 레이어별 항목

### 디자인 시스템 레이어 ✅

- 색상 토큰 라이트/다크 적응형 완전 구현 (24개 시맨틱 컬러)
- 뱃지 7색 팔레트 `BadgeTone` enum
- 타이포 스케일 9단계 `AppFont` enum
- 간격 9단계 / 라운드 6단계 / 그림자 4종
- iOS 26 Liquid Glass 시그니처 + 폴백 체계
- LiquidButton 시그니처 (빛 띠 루프 + reduce-motion 대응)
- BLCard / BLBadge / BLChip / BLSectionHead / PhotoPlaceholder

### 데이터 레이어 ✅ (인메모리)

- 5개 핵심 엔티티 (`Pregnancy·Child·GrowthRecord·DiaryEntry·VaccineRecord`)
- `PregnancyStatus` 상태 머신 4상태
- `PregnancyTransition.makeChild` 순수 함수 (3단계 검증)
- `AppStore.commitBirthTransition` 원자적 커밋 (인메모리)
- `Codable` 준수 → JSON 익스포트 기반 마련

### 알림 레이어 ✅

- `NotificationScheduling` 프로토콜 (테스트 mock 교체 가능)
- `pregnancyEndedInLoss` → 즉시 알림 취소 파이프라인
- 식별자 prefix 규칙 (`"preg-<pregnancyId.uuidString>"`)
- EventBus 구독 → 자동 취소 (사용자 부담 제로)

### 공통 이벤트 버스 ✅

- Combine `PassthroughSubject` 싱글톤
- 3개 이벤트 (`milestoneAchieved / recordSaved / pregnancyEndedInLoss`)
- 기능 간 연결 표준화 완료 (v2 대규모 리팩터링 방지 기반)

---

## 5. 남은 과제 (Phase 3)

### 5-1. CoreData + CloudKit 영속화 (최고 우선순위)

현재 `AppStore`는 인메모리 전용. 앱 재시작 시 모든 데이터 초기화.

| 과제 | 상세 |
|---|---|
| CoreData 모델 파일 생성 | `Pregnancy·Child·GrowthRecord·DiaryEntry·VaccineRecord` 5개 Entity |
| 전환 트랜잭션 래핑 | `commitBirthTransition`을 `NSManagedObjectContext` 단일 `save()`로 래핑 |
| 불완전 전환 복구 | 앱 시작 시 `(status == .delivered) && (Child 없음)` 감지 → 복구 플로우 |
| 날짜 UTC 정규화 | 시간대 DST 경계 오류 방지 (phase3-risk-audit A-1) |
| CloudKit 동기화 | 가족 공유 최대 6인. 사진은 로컬/iCloud 저장 (무료), 서버 백업은 Pro. |
| 상실 상태 전파 | `pregnancyEndedInLoss`를 CloudKit 알림으로 가족 기기에 선전파 → 임신 알림 일시 중단 |

### 5-2. 외부 API 연동

| API | 용도 | 비용 | 버전 |
|---|---|---|---|
| 질병관리청 예방접종도우미 | 예방접종 스케줄 | 무료 | v1 |
| 건강보험심사평가원 | 소아과·약국 정보 | 무료 | v1 |
| 카카오맵 로컬 API | 주변 장소 (월 30만 건 무료) | 무료 | v1 |
| 복지로 API | 아동수당·부모급여·첫만남이용권 | 무료 | v2 |
| KATSA/KERI 리콜 DB | 카시트 등 리콜 조회 | 무료 | v2 |

> **주의**: API 키 관리 — v1 백엔드 없는 구간에서 카카오맵 키 노출 방지 (phase3-risk-audit B4).

### 5-3. 화면 본구현

| 화면 | 우선순위 | 특이사항 |
|---|---|---|
| 온보딩 (5단계) | 최고 | 게스트 데이터 로컬 보관 → 가입 시 마이그레이션 |
| 홈 (3레이아웃 A/B/C) | 최고 | 우선순위 엔진, 임신 모드 분기, loss 상태 카드 숨김 |
| 기록 탭 (타임라인/차트/접종) | 최고 | 사진 스크롤 성능(썸네일 캐시), Swift Charts 통합 |
| 빠른 기록 시트 | 최고 | 2탭 완료 UX 지표 보호 |
| 동네 > 주변·응급 | 높음 | 응급 다크 풀스크린, 신뢰 장치 |
| 성장 카드 공유 | 높음 | ImageRenderer 구현 |
| 가계부 탭 | v2 | Supabase 이후 |
| 내정보 > 뱃지·Pro | v2 | StoreKit 2 연동 |
| 동네 > 마켓 | v2 | Supabase 이후 |
| 동네 > 크루 | v3 | 밀도 게이팅, 원격 피처 플래그 |

### 5-4. 미완성 테스트 (Phase 3 필수 추가)

| 케이스 | 파일 | 감사 ID |
|---|---|---|
| 시스템 시간대 `America/Los_Angeles` 오버라이드 후 임신 주수 계산 | AgeCalculatorTests | A-1 |
| `LMP > 오늘` 입력 → nil 반환 + UI 처리 | AgeCalculatorTests | A-3 |
| 윤년 2024-02-29 출생 → 2025-02-28 vs 2025-03-01 월령 | AgeCalculatorTests | A-4 |
| AppStore 검증 실패 → `pregnancies` 상태 무변경 확인 | AppStoreTransitionTests | B-1 |
| 정상 전환 후 EventBus `recordSaved` 발행 확인 | AppStoreTransitionTests | B-1 |
| `delivered → active` 등 금지 전이 차단 | AppStoreTransitionTests | B-2 |
| `pregnancyEndedInLoss` 발행 → mock scheduler `cancelPregnancyNotifications` 호출 | NotificationServiceTests | C-1, H4 |
| 스냅샷 테스트 도입 (화면 본구현 완료 후) | SnapshotTests | — |

### 5-5. 접근성 완성

| 항목 | 상태 | 과제 |
|---|---|---|
| Dynamic Type | 구현 기반 완료 | Pretendard Variable 번들 후 `relativeTo:` 매핑 유지 |
| VoiceOver | 가이드 완료 | 화면 본구현 시 모든 인터랙티브 요소 `.accessibilityLabel` 명시 |
| 색약 대응 | 3중 인코딩 패턴 확립 | 구현 시 일관 적용 |
| 히트 타깃 | 44×44pt 기준 수립 | 구현 시 준수 |
| 응급 모드 접근성 | 설계 완료 | 전화 버튼 최대 크기, 최소 정보 |
| 야간 초저휘도 모드 | 미착수 | Phase 3 구현 |
| 조부모 심플 뷰 토글 | 미착수 | Phase 3 구현 |

### 5-6. SPM 모듈화 (Phase 3 이후)

현재 단일 앱 타깃(빌드 우선). 화면 본구현 완료 후 분리 예정.

```
BLCore          → 이벤트 버스·공통 모델·AgeCalculator
BLDesignSystem  → AppColors·AppFont·AppMetrics·LiquidGlass·Components
BLGrowth        → 성장 기록·예방접종·성장 카드 (v1)
BLPregnancy     → 임신 기록·출산 전환 (v1)
BLInfra         → 주변 인프라·응급 모드 (v1)
BLMarket        → 중고 마켓·렌탈 (v2~)
BLBudget        → 가계부·정부지원금 (v2~)
BLCrew          → 동네 크루·커뮤니티 (v3~)
```

### 5-7. 위젯 & Apple Watch (WidgetKit)

| 위젯 | 내용 |
|---|---|
| 오늘의 할 일 | 접종 예정·지원금 마감 |
| 아이 요약 | 최근 사진 + 월령 + D+일 |
| 주변 응급 | 현재 영업 중 소아과 유무 |

> **중요**: 위젯 타임라인 Provider가 `loss` 상태를 읽어 임신 콘텐츠를 숨기는 로직 필수 (민감 영역).

### 5-8. Pretendard Variable 폰트

현재 시스템 폰트 근사 사용. Asset Catalog에 Pretendard Variable 번들 후 `AppFont`를 `relativeTo:` 매핑으로 전환. Asset Catalog named color 이관도 동시 진행.

---

## 6. v1 ~ v3 로드맵 연결

### v1 MVP — 유저 확보 (MAU 1만 목표)

| 기능 | 상태 |
|---|---|
| 성장 기록 & 육아 일지 (기능 2) | 파운데이션 완료, 화면 본구현 Phase 3 |
| 임신 기록 & 태아 일지 (기능 1) | 파운데이션 완료, 화면 본구현 Phase 3 |
| 주변 인프라 & 응급 모드 (기능 3) | Phase 3 (외부 API 연동 포함) |
| 온보딩 (기능 9) | Phase 3 |
| 홈 화면 (기능 10) | Phase 3 |
| 알림 전략 (기능 11) | 알림 레이어 완료, 스케줄 로직 Phase 3 |
| 접근성 (기능 13) | 기반 완료, 화면 적용 Phase 3 |

**v1 수익**: 없음. 신뢰 구축이 목표.

### v2 — Pro 구독 + 마켓 수수료 (MAU 1.5만~3만 목표)

| 기능 | 내용 |
|---|---|
| 중고 마켓 & 렌탈 (기능 4) | Supabase 연동. 수수료 6개월 0% 론칭. |
| 가계부 & 정부지원금 (기능 5) | Supabase 연동. 복지로 API. |
| Pro 구독 | 월 3,900원 / 연 29,000원. StoreKit 2. 무제한 사진·AI 캡션·워터마크 제거. |
| 뱃지 & 신뢰도 (기능 7) | 거래·기록·커뮤니티 뱃지 4티어. |
| 내정보 탭 전체 | Pro 업셀·뱃지 컬렉션·데이터 익스포트. |

### v2.5 — 렌탈 수수료

| 기능 | 내용 |
|---|---|
| 렌탈 거래 | 거래액 10~15% 수수료. 보증금 에스크로. |
| 마이데이터 카드 연동 | 법인화 후. 가계부 자동 수집 강화. |

### v3 — 동네 크루 + 커뮤니티 (MAU 5만~10만 목표)

| 기능 | 내용 |
|---|---|
| 동네 크루 (기능 6) | 밀도 게이팅 + 거점 집중 론칭(분당·일산·세종). |
| 게시판형 커뮤니티 | 경량 단계(댓글·정보공유) → 운영 검증 후 풀 커뮤니티. |
| AI 일지 초안 | 서버 LLM Pro 기능. 사진 → 캡션 초안. |
| 위젯 & Apple Watch | WidgetKit 오늘의 할 일·아이 요약·응급. |
| 안드로이드 | KMP 또는 Flutter 재설계 검토. |

---

## 7. 핵심 리스크 (Phase 3 진입 전 필수 해결)

| 리스크 | 내용 | 우선순위 |
|---|---|---|
| R1 임신→출산 전환 원자성 | CoreData 단일 `save()` 래핑. 불완전 전환 복구 로직. | 최고 |
| R2 사진 타임라인 성능 | 썸네일 사전생성·캐시 전략 수립. 대량 사진 스크롤 최적화. | 높음 |
| R3 외부 API 키 관리 | v1 백엔드 없는 구간에서 카카오맵 키 노출 방지. | 높음 |
| R4 성별 중립 뱃지 | '골든 맘/파파' 호칭 선택형 + 중립 옵션 구현. | 원칙 |
| R5 시간대·DST 경계 | 날짜 저장 UTC 정규화. 시간대 변경 시 임신 주수 오류 방지. | 높음 |
| R6 상실 상태 전파 | CloudKit 동기화 시 가족 기기 임신 알림 일시 중단 로직. | 최고 (민감) |
| R7 WidgetKit loss 상태 | 위젯 타임라인이 `loss` 상태 읽어 임신 콘텐츠 숨기기. | 높음 (민감) |

---

## 8. 진척 지표 (북극성)

SPEC.md 기능 15 기준으로 허영 지표 대신 습관·신뢰 중심 측정.

| 지표 | 목표 | 측정 시점 |
|---|---|---|
| WAU 중 주 3회 이상 기록/방문 비율 | — | v1 론칭 후 |
| 빠른 기록 완료율 (FAB→저장 완료) | 최대화 | v1 |
| D30 리텐션 | 60% 이상 | v1 |
| 임신 등록 → 출산 전환율 | 70% 이상 | v1 |
| 가족 공유 활성화율 | 40% 이상 | v1 |
| 크래시율 | 0에 수렴 | 상시 |
| 성장 카드 공유율 | MAU 25% 이상 | v1 |
| 마켓 거래 완료율 | 채팅의 40% 이상 | v2 |
