# BabyLog 데이터 모델 & 영속화 가이드

> 최종 업데이트: 2026-06-17 · 입력: `App/Sources/Data/Models.swift`, `App/Sources/Data/BoardModels.swift`, `App/Sources/Data/PregnancyTransition.swift`, `App/Sources/Data/AppStore.swift`, `App/Sources/Data/CloudSyncService.swift`, `App/Sources/Core/EventBus.swift`, `App/Sources/Notifications/NotificationService.swift`, `CLAUDE.md`, `team/debug/phase3-risk-audit.md`

---

## 1. 도메인 모델 개요

BabyLog의 핵심 데이터는 다섯 개 엔티티(`App/Sources/Data/Models.swift`) + 성장 보드 2개(`BoardModels.swift`)로 구성됩니다. 모든 엔티티는 `Identifiable · Codable · Equatable`을 준수합니다.

### 엔티티 일람

| 엔티티 | 역할 | 주요 필드 | 연결 키 |
|---|---|---|---|
| `Pregnancy` | 임신 기록 (태아 시절 전체) | `id · lmpDate · eddDate · fetusCount · nickname · clinic · status` | — |
| `Child` | 출산 이후 아이 프로필 | `id · name · birthDate · gender · profileImageRef · caregiverRole · pregnancyId` | `pregnancyId → Pregnancy.id` |
| `GrowthRecord` | 신장·체중·두위 기록 | `id · childId · date · heightCm · weightKg · headCircumferenceCm` | `childId → Child.id` |
| `DiaryEntry` | 사진·이정표·메모 다이어리 | `id · childId · date · recordType · content · milestone` | `childId → Child.id` |
| `VaccineRecord` | 예방접종 일정·완료 이력 | `id · childId · vaccineId · scheduledDate · completedDate · hospital` | `childId → Child.id` |
| `GrowthBoard` | 성장 보드 (자유 캔버스) | `id · childId · title · isPrimary · cards · connections · stickers · updatedAt` | `childId → Child.id` |
| `BoardCard` | 보드 내 사진/메모 카드 | `id · kind(photo/memo) · photoRef · sourceEntryId · title · 위치·회전` | `sourceEntryId → DiaryEntry.id`(참조 시) |

> **성장 보드**(`App/Sources/Data/BoardModels.swift`)는 위 핵심 5개와 별도 파일에 정의. 모든 필드 `decodeIfPresent` 하위호환. 등급제: 무료 1개·Pro 최대 100개(`GrowthBoard.maxPerChild = 100`), 대표(`isPrimary`) 1개는 무료도 편집·나머지는 Pro 전용(`AppStore.isBoardEditable`). 카드 사진은 `sourceEntryId`로 소유/참조를 구분(ref-count) — 기록 삭제 시 참조 카드는 사진을 승계해 유실을 막는다. 보드는 **로컬/개인 iCloud(CloudKit)만**, 우리 서버에 올리지 않는다.

### Pregnancy 상태 머신

`PregnancyStatus` enum은 임신 기록의 전체 생애주기를 표현합니다.

```swift
enum PregnancyStatus: String, Codable {
    case active     // 임신 진행 중 (기본값)
    case delivered  // 출산 완료 → Child 승계
    case loss       // 상실 (유산·사산) → 모든 임신 알림 즉시 차단
    case paused     // 기록 멈춤 모드 (사용자 요청)
}
```

**허용 전이 규칙** (현재 코드에 강제되지 않음 — Phase 3 구현 과제):

| 현재 상태 | 허용 전이 | 금지 전이 |
|---|---|---|
| `active` | `delivered`, `loss`, `paused` | — |
| `paused` | `active`, `loss` | `delivered` |
| `delivered` | — (최종) | `active`, `loss`, `paused` |
| `loss` | — (최종) | 모든 전이 |

> **Phase 3 과제**: `PregnancyStatus`에 `canTransitionTo(_ next:) -> Bool` 메서드를 추가해 전이 규칙을 단일 소스로 관리해야 합니다 (`team/debug/phase3-risk-audit.md` B-2 참조).

---

## 2. Pregnancy → Child 승계 흐름

임신 기록이 출산 시점에 아이 프로필로 매끄럽게 이어지는 것이 BabyLog의 핵심 가치입니다. 태아 시절의 배 사진 타임라인·태명·임신 기록은 출산 후에도 아카이브로 영구 보존됩니다.

### 승계 데이터 매핑

```
임신 프로필 (Pregnancy)
  ├─ Pregnancy.nickname (태명)          →  Child의 이름은 사용자가 직접 입력
  ├─ Pregnancy.eddDate (예정일)         →  BirthTransitionInput.birthDate (실제 생년월일)
  ├─ Pregnancy.id (임신 ID)            →  Child.pregnancyId (연속성 링크, 영구 보존)
  └─ 배 사진 (Phase 3: MaternalRecord)  →  기록 탭 "태아 시절" 섹션에 자동 노출 예정
                ↓ 출산 전환
아이 프로필 (Child, pregnancyId 로 Pregnancy 에 연결)
  ├─ DiaryEntry (사진·이정표) ← 배 사진과 타임라인 연속
  ├─ GrowthRecord (신장·체중·두위)
  └─ VaccineRecord (예방접종 이력)
```

### 2단계 전환 로직

출산 전환은 두 계층으로 분리됩니다.

**계층 1 — 순수 함수 검증·생성** (`App/Sources/Data/PregnancyTransition.swift`):

```swift
// PregnancyTransition.makeChild(from:input:) — 부수 효과 없음
// 검증 순서:
// 1. pregnancy.status == .active 확인
// 2. input.childName 공백 제거 후 비어있지 않음 확인
// 3. input.birthDate >= pregnancy.lmpDate 확인 (lmpDate가 nil이면 생략)
// 반환: Result<Child, BirthTransitionError>
```

가능한 에러:

| 에러 | 발생 조건 |
|---|---|
| `BirthTransitionError.notActive` | `pregnancy.status != .active` |
| `BirthTransitionError.emptyName` | 공백·탭·개행 제거 후 이름이 빈 문자열 |
| `BirthTransitionError.birthDateBeforeLMP` | `birthDate < lmpDate` (LMP가 있는 경우만) |

**계층 2 — 원자적 상태 커밋** (`App/Sources/Data/AppStore.swift`):

---

## 3. 원자적 전환 — AppStore.commitBirthTransition

인메모리 스토어에서 Pregnancy→Child 전환을 단일 연산으로 수행합니다. **검증이 하나라도 실패하면 `pregnancies`와 `children` 어느 쪽도 변경되지 않습니다.**

```swift
// AppStore.commitBirthTransition(pregnancyId:input:)
// 성공 흐름:
// 1. pregnancyId 로 Pregnancy 탐색 → 없으면 .failure(.notActive), 무변경
// 2. PregnancyTransition.makeChild(from:input:) 호출 → .failure면 무변경
// 3. 검증 통과 시에만:
//    - pregnancies[index].status = .delivered  (기존 Pregnancy 유지)
//    - children.append(child)                  (새 Child 추가)
//    - EventBus.shared.publish(.recordSaved(childId: child.id))
// 반환: Result<Child, BirthTransitionError>
```

### 원자성 보장 범위와 현재 한계

현재 AppStore는 **인메모리 배열을 대상으로 원자성을 보장**합니다. 두 배열(`pregnancies`, `children`)의 동시 변경이 단일 함수 호출 내에서 이루어져, 부분 변경이 외부에 노출되지 않습니다.

> **중요한 한계**: 앱이 상태 변경 도중 강제 종료되거나 CoreData 저장에 실패하면 불완전한 전환이 발생할 수 있습니다 (Pregnancy는 `.delivered`이나 Child가 없는 상태). CoreData 단계에서는 반드시 `NSManagedObjectContext`의 단일 `save()` 호출로 묶고, 재시작 시 불완전 전환 감지·복구 로직을 추가해야 합니다 (`team/debug/phase3-risk-audit.md` B-1 참조).

---

## 4. 공통 이벤트 버스 (AppEvent)

기능 간 연결을 초기부터 표준화해 v2 대규모 리팩터링을 방지합니다. 파일: `App/Sources/Core/EventBus.swift`.

```swift
// 이벤트 정의
enum AppEvent {
    case milestoneAchieved(childId: UUID, milestone: String)
    case recordSaved(childId: UUID)
    case pregnancyEndedInLoss(pregnancyId: UUID)
}

// 싱글톤 접근
EventBus.shared.publish(.pregnancyEndedInLoss(pregnancyId: id))

// 구독 예시
EventBus.shared.events
    .sink { event in /* 처리 */ }
    .store(in: &cancellables)
```

구현체: Combine `PassthroughSubject<AppEvent, Never>` 싱글톤.

### 이벤트 활용 시나리오

| 이벤트 | 트리거 | 수신 측 반응 |
|---|---|---|
| `milestoneAchieved` | 이정표 달성 기록 | 마켓에서 관련 월령 매물 추천 (v2~) |
| `recordSaved` | 사진·기록 저장 | 홈 리텐션 카운터 갱신 |
| `pregnancyEndedInLoss` | 상실 상태 변경 | 모든 임신 알림 즉시 차단 (**민감 영역**) |

---

## 5. 상실 알림 차단 — 민감 영역 원칙

유산·사산 등 상실 상황에서 임신 알림이 계속 발송되는 것은 **절대 금지**입니다 (`CLAUDE.md` 민감 영역). 이를 위해 `NotificationService`가 `EventBus`를 구독해 상실 이벤트를 즉시 처리합니다.

### 알림 차단 흐름

```
사용자가 상실 기록 입력
    │
    ▼
Pregnancy.status = .loss 변경
    │
    ▼
EventBus.shared.publish(.pregnancyEndedInLoss(pregnancyId:))
    │
    ▼
NotificationService.start() 에서 구독 중인 sink 가 이벤트 수신
    │
    ▼
UNNotificationScheduler.cancelPregnancyNotifications(pregnancyId:)
    │
    ▼
UNUserNotificationCenter.getPendingNotificationRequests { ... }
    prefix "preg-<pregnancyId>" 와 일치하는 식별자 일괄 제거
    UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)
```

### NotificationService 구조

`App/Sources/Notifications/NotificationService.swift`:

- `NotificationScheduling` 프로토콜 — 테스트 시 mock으로 교체 가능
- `UNNotificationScheduler` — 구체 구현체 (식별자 prefix: `"preg-<pregnancyId.uuidString>"`)
- `NotificationService` — EventBus 구독 관리, `start()` 호출로 활성화

### 민감 영역 설계 원칙

1. **즉시성**: `pregnancyEndedInLoss` 이벤트 수신 즉시 취소 처리. 30초·1분 딜레이 없음.
2. **사용자 부담 제로**: 사용자가 "알림 끄기" 설정을 별도로 하지 않아도 자동 차단.
3. **취소 범위**: 해당 `pregnancyId`에 연결된 모든 보류 알림 일괄 제거 (주차 알림·태아 가이드·권유 알림 구분 없이).
4. **카피 원칙**: 상실 이후 UI에서 "○○주차 가이드", "태동을 기록해보세요" 등 임신 관련 카드가 잔류하지 않아야 합니다. 홈 화면 우선순위 카드, 위젯(WidgetKit) 타임라인도 `loss` 상태를 읽어 임신 콘텐츠를 숨겨야 합니다 (Phase 3 구현 과제).

> **알림 식별자 명명 규칙**: 모든 임신 관련 로컬 알림의 identifier는 반드시 `"preg-<pregnancyId.uuidString>"` prefix로 시작해야 합니다. 이 규칙을 지키지 않으면 상실 시 해당 알림이 취소되지 않습니다.

---

## 6. 현재 영속화 현황 — JSON 디스크 + 개인 iCloud 백업

`AppStore`(`@MainActor ObservableObject`)는 전체 상태를 `PersistableState`로 묶어 **JSON으로 디스크에 영속화**합니다(`CodablePersistence`, App Group 컨테이너). `objectWillChange` 기반 autoPersist로 변경 시 자동 저장되고, 앱 재시작·기기 재설치 후에도 유지됩니다.

| 계층 | 구현 | 비고 |
|---|---|---|
| 로컬 디스크 | `CodablePersistence` → `PersistableState`(임신·아이·성장·다이어리·접종·가계부·**성장 보드**·prefs) | App Group, JSON. 모든 디코딩 `decodeIfPresent` 하위호환 |
| 개인 iCloud 백업 | `CloudSyncService`(`BL_CLOUDKIT`, 컨테이너 `iCloud.com.vibelab.babylog`) | `CKContainer.default().privateCloudDatabase` — **사용자 개인 iCloud, 우리 서버 X** |
| 사진 백업 | 보드 전용 사진 등 `allPhotoRefs`를 iCloud로 push | 아동 기록 원본은 로컬/개인 iCloud만 |

**CloudKit 저장 정책**: `push()`는 `modifyRecords(saving:deleting:savePolicy: .allKeys)`(last-writer-wins)를 사용합니다. 기본 `database.save()`(`.ifServerRecordUnchanged`)는 "serverRecordChanged / client oplock error"를 일으켜 백업이 실패하므로 쓰지 않습니다. push 성공 시 `bl_last_cloud_backup_at`에 시각을 기록(설정 화면 "마지막 백업" 표시). 자동 백업은 `.background` scenePhase + `BGProcessingTask` 캐치업으로 수행하며, 로그인 안 됨(`accountStatus() != .available`)이면 앱 진입 1회 알림 + 설정 경고로 안내합니다.

> 참고: 앱 로그인(가족 피드·크루, Supabase)과 기기 iCloud 백업(Apple ID·CloudKit)은 **별개**입니다 — 백업은 후자만 사용합니다.

---

## 7. 향후 영속화 계획 — CoreData 마이그레이션 + CKShare

현재 영속화는 JSON 디스크 + 개인 iCloud(CloudKit) 백업이 라이브입니다(§6). 아래는 그 위에 더할 후속 단계입니다.

### CoreData 마이그레이션 (후속)

| 항목 | 내용 |
|---|---|
| 대상 엔티티 | `Pregnancy`, `Child`, `GrowthRecord`, `DiaryEntry`, `VaccineRecord`, `GrowthBoard` |
| 전환 트랜잭션 | `AppStore.commitBirthTransition`을 `NSManagedObjectContext` 단일 `save()`로 래핑 |
| 불완전 전환 복구 | 앱 시작 시 `(status == .delivered) && (pregnancyId를 가진 Child 없음)` 감지 → 복구 플로우 |
| 시간대 정규화 | 날짜 저장 시 UTC 기준으로 정규화, 표시 시에만 현지 시간대 변환 (A-1 리스크 대응) |

### CloudKit 백업 — 현황 및 다음

| 항목 | 내용 |
|---|---|
| 현황(라이브) | `CloudSyncService`가 `PersistableState` 전체를 개인 iCloud private DB에 백업·복원(§6). 저장 정책 `.allKeys`(last-writer-wins). |
| 사진 정책 | **아동 기록 원본(성장·일기·접종·가계부·성장 보드)은 로컬/개인 iCloud만, 우리 서버 X.** 우리 서버(R2)는 **가족 사진 공유**에 한해 사용(무료 2인·Pro 8명). — `CLAUDE.md` 절대 원칙 |
| 부부 전체데이터 공유 (v2) | CKShare 기반 부부 간 앱 전체 데이터 동기화(개인 iCloud, 우리 서버 X). 2번째 Apple ID 필요로 보류 중. |
| 상실 상태 전파 | `pregnancyEndedInLoss` 상태를 CloudKit 알림으로 가족 기기에 먼저 전파 → 나머지 임신 알림 일시 중단 (C-2 리스크 대응) |

---

## 8. 데이터 주권 — 표준 익스포트

`CLAUDE.md` 절대 원칙: "사용자가 언제든 표준 포맷으로 데이터를 내보낼 수 있어야 한다."

| 항목 | 내용 |
|---|---|
| 익스포트 포맷 | JSON (모든 엔티티 포함, `Codable` 준수로 즉시 직렬화 가능) |
| 포함 데이터 | Pregnancy·Child·GrowthRecord·DiaryEntry·VaccineRecord 전체 |
| 사진 | 로컬 파일 경로 목록 포함 (실제 바이너리는 사용자 직접 저장) |
| 진입점 | 내정보 탭 > 데이터·프라이버시 섹션 |
| 무료/Pro 구분 없음 | 데이터 익스포트는 모든 사용자에게 제공. "데이터 인질극" 절대 금지. |

> 현재 `Models.swift`의 모든 구조체가 `Codable`을 준수하므로, `JSONEncoder`를 사용한 익스포트 기반은 이미 마련되어 있습니다.
