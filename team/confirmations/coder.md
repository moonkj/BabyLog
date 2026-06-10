# Coder 확인 보고서 — Phase 0

**작성자:** Teammate 1 (Coder)  
**작성일:** 2026-06-10  
**대상 문서:** CLAUDE.md, SPEC.md v0.2, TEAM.md  
**단계:** Phase 0 — 확인만, 코드 미작성

---

## (a) 데이터 모델 정리

### CoreData 엔티티 목록

#### 기능 1 — 임신 기록

| Entity | 주요 필드 | 비고 |
|---|---|---|
| `Pregnancy` | id (UUID), lmpDate, eddDate, actualBirthDate, fetusCount, nickname, clinic, status (active / paused / completed / loss) | status 필드가 '기록 멈춤' 모드 구현의 핵심 |
| `MaternalRecord` | id, pregnancyId, date, weight, bellyPhotoLocalURL, symptom, mood | 사진은 로컬 URL만 저장(서버 전송 금지 원칙) |
| `FetalMovement` | id, pregnancyId, date, count, memo | 말기 건강 체크용 간단 카운터 |
| `PrenatalCheckup` | id, pregnancyId, weekNumber, scheduledDate, completedDate, ultrasoundPhotoLocalURL, memo | 초음파 사진도 로컬 URL만 |

#### 기능 2 — 성장 기록

| Entity | 주요 필드 | 비고 |
|---|---|---|
| `Child` | id (UUID), name, birthDate, gender, profileImageLocalURL, caregiverRole, pregnancyId (nullable), isSimpleViewEnabled | pregnancyId로 임신→아이 연결 유지 |
| `GrowthRecord` | id, childId, date, heightCm, weightKg, headCircumferenceCm | 단위 토글은 UI 레이어, 저장은 cm/kg 고정 |
| `DiaryEntry` | id, childId, date, recordType (enum), content, milestone (enum), customFieldsJSON, photoLocalURLs | customFieldsJSON으로 수유/수면 등 스키마 확장 대비 |
| `VaccineRecord` | id, childId, vaccineId, vaccineNameCache, scheduledDate, completedDate, hospital, lotNumber | API 캐시 필드로 오프라인 대응 |
| `AdvancedLog` | id, childId, date, logType (feed/sleep/diaper), value, memo | 소수 니즈, 고급 기록 모드에서만 사용 |
| `ShareCard` | id, childId, photoLocalURL, dataPosition (enum), selectedFields, aspectRatio (enum), watermarkEnabled | 카드 설정 저장, 재생성 용이 |

#### 기능 5 — 육아 가계부

| Entity | 주요 필드 | 비고 |
|---|---|---|
| `Expense` | id, childId (nullable), amount, category (enum), date, memo, receiptImageLocalURL, payerTag, autoSource (enum: manual/market/subscription) | autoSource로 자동 기록 추적 |
| `RecurringExpense` | id, childId, amount, category, startDate, interval (enum: monthly/weekly) | 월정액 자동 등록 |
| `Subsidy` | id, name, eligibilityMonthStart, eligibilityMonthEnd, amount, applyURL, checklistJSON | 정부지원금 데이터, 서버/번들 갱신 |

#### 기능 7 — 뱃지 시스템 (v2 이후 필요, 모델만 사전 정의)

| Entity | 주요 필드 | 비고 |
|---|---|---|
| `Badge` | id, name, category (enum), tier (enum), conditionJSON, colorHex, isSpecial, isRevocable | Supabase 서버 데이터 |
| `UserBadge` | userId, badgeId, earnedAt, isPinned, displayOrder | 서버 저장 |
| `UserTier` | userId, tier, calculatedAt, tradeCount, avgRating, disputeCount | 분기 재산정 |
| `BadgeEvent` | userId, badgeId, eventType (enum: earned/revoked), createdAt | 감사 로그 |

---

### Pregnancy → Child 승계 연속성 — 초안 설계 견해

CLAUDE.md와 SPEC 1.3의 핵심 가치는 "태아 시절부터 성장까지 끊김 없는 하나의 여정"이다.

**제안 모델:**

```
Pregnancy.id ─(1:1)─▶ Child.pregnancyId (nullable)
```

- `Child.pregnancyId`가 null이면 직접 생성한 아이 프로필(임신 기록 없음).
- `Child.pregnancyId`가 설정되면 임신 기록이 있는 아이 — 승계 완료 상태.
- `Pregnancy.actualBirthDate`를 `Child.birthDate`로 복사해 확정.
- `Pregnancy.nickname`을 `Child.name` 제안값으로 온보딩에 자동 채움.
- `MaternalRecord.bellyPhotoLocalURL` 목록을 타임라인에서 `DiaryEntry`와 시간순 혼합 표시 — 배 사진과 성장 사진이 하나의 연속 타임라인을 구성.
- 임신 기록은 삭제하지 않고 `Pregnancy.status = .completed`로 보존, 아카이브 탭에서 조회 가능하게.
- 상실 케이스: `Pregnancy.status = .loss`로 전환 시 모든 주차 알림 즉각 중단, Child 프로필로 승계하지 않음. 기록 보존/삭제 선택권은 유저에게 일임.

---

## (b) 기술 스택 준비도 점검

### SwiftUI (iOS 16+)

- **준비도: 높음.** iOS 16은 2022년 출시로 2026년 기준 시장 보급률이 충분히 높음(99% 이상 예상).
- NavigationStack, Charts, PhotosUI 등 v1에 필요한 모든 API가 iOS 16에서 안정화됨.
- 주의: `ImageRenderer`는 iOS 16+에서 사용 가능 — 타겟 일치.

### CoreData + CloudKit

- **준비도: 중간.** `NSPersistentCloudKitContainer` 기반 구현은 검증된 패턴이나 다음 주의사항 있음:
  - CloudKit 동기화는 충돌 해소(conflict resolution) 전략이 명시적으로 필요함. 부부 동시 편집 시 GrowthRecord 충돌 케이스가 빈번히 발생할 수 있음.
  - 로컬 전용(사진 URL 등)과 CloudKit 동기화 대상을 Configuration으로 명시적 분리 필수.
  - 게스트 → 로그인 전환 시 데이터 마이그레이션 플로우 별도 설계 필요 (SPEC 8.1: 게스트 데이터 마이그레이션).
  - CloudKit public DB는 크루/마켓용, private DB는 가족 기록용으로 용도 분리.

### Swift Charts

- **준비도: 높음.** iOS 16 네이티브. 성장 곡선(WHO 데이터 오버레이), 체중 추이, 가계부 차트 모두 구현 가능.
- WHO 성장 곡선 데이터는 연령·성별별 LMS 파라미터를 번들에 포함해 오프라인 백분위 계산 필요. 데이터 변환 로직 사전 구현 필요.

### PhotosUI

- **준비도: 높음.** `PHPickerViewController` 기반으로 사진 라이브러리 최소 권한 접근. SPEC 8.4의 권한 전략과 일치.
- 동영상(30초 이하) 처리 시 `AVFoundation`으로 압축·썸네일 추출 로직 필요.

### ImageRenderer + Core Graphics

- **준비도: 중간.** `ImageRenderer`로 SwiftUI 뷰를 이미지로 렌더링하는 것은 iOS 16 API이나 성능에 주의 필요.
  - 고해상도 사진 위에 텍스트 오버레이 합성 시 메인 스레드 블로킹 위험 → 백그라운드 렌더링 필수.
  - 9:16(스토리) 비율 렌더링은 메모리 사용량이 큼 — 해상도 제한 정책 필요.
  - `UIActivityViewController` 연동은 표준 패턴으로 위험도 낮음.

---

## (c) v1 MVP SPM 모듈 분리 제안

v1 MVP 범위는 **성장기록(기능 2) + 주변 인프라(기능 3)**이며, 임신 기록(기능 1)의 일부 모델도 포함됨.

### 제안 패키지 구조

```
BabyLog (메인 앱 타겟)
├── Packages/
│   ├── BLCore                  # 공통 기반 (항상 먼저 구축)
│   │   ├── EventBus            # 기능 간 이벤트 버스 (AppEvent 프로토콜)
│   │   ├── StringResources     # 다국어 문자열 리소스 (LocalizedStringKey 래퍼)
│   │   ├── DesignSystem        # 시맨틱 컬러, SF Symbols 래퍼, Typography
│   │   └── DataExport          # 표준 포맷 내보내기 (JSON/CSV)
│   │
│   ├── BLData                  # 데이터 레이어
│   │   ├── CoreDataStack       # NSPersistentCloudKitContainer 설정
│   │   ├── Models              # CoreData 엔티티 Swift 클래스
│   │   └── Repositories        # Repository 패턴 (ChildRepository, GrowthRepository 등)
│   │
│   ├── BLPregnancy             # 기능 1 — 임신 기록
│   │   ├── Domain              # PregnancyService, WeekCalculator
│   │   └── UI                  # PregnancyView, BellyTimelineView
│   │
│   ├── BLGrowth                # 기능 2 — 성장 기록 (v1 핵심)
│   │   ├── Domain              # GrowthService, WHOChartCalculator, MilestoneDetector
│   │   ├── UI                  # DiaryTimelineView, GrowthChartView, ShareCardView
│   │   └── VaccineService      # 질병관리청 API 클라이언트
│   │
│   ├── BLInfra                 # 기능 3 — 주변 인프라 (v1 핵심)
│   │   ├── Domain              # PlaceService, EmergencyModeService
│   │   ├── HiraAPIClient       # 건강보험심사평가원 클라이언트
│   │   └── KakaoMapClient      # 카카오맵 로컬 API 클라이언트
│   │
│   └── BLNotification          # 기능 10 — 알림 전략
│       ├── NotificationScheduler
│       └── ActivityTimeoutDetector  # 미사용 신호 감지 (온디바이스)
```

### 분리 원칙

- `BLCore`와 `BLData`는 모든 기능 패키지의 의존 대상, 역방향 의존 금지.
- 기능 패키지 간 직접 의존 금지 — 연결은 반드시 `BLCore.EventBus`를 통해.
- v2(마켓/가계부) 추가 시 `BLMarket`, `BLBudget` 패키지만 신규 추가하면 기존 코드 무영향.

### 이벤트 버스 예시 이벤트 (v1 기준)

```swift
// BLCore/EventBus/AppEvent.swift
enum AppEvent {
    case milestoneAchieved(childId: UUID, milestone: Milestone)
    case vaccineScheduleDue(childId: UUID, vaccineName: String, daysLeft: Int)
    case pregnancyStatusChanged(pregnancyId: UUID, newStatus: PregnancyStatus)
    case diaryEntryCreated(childId: UUID, entryId: UUID)
}
```

---

## (d) v1 외부 API 연동 정리

### 1. 질병관리청 예방접종도우미 API

| 항목 | 내용 |
|---|---|
| 목적 | 월령별 예방접종 스케줄 조회 |
| 비용 | 무료 (공공데이터포털) |
| 인증 | 공공데이터포털 API 키 발급 필요 |
| 방식 | REST API / JSON |
| 호출 시점 | 아이 프로필 등록 시 1회 + 월령 갱신 시 |
| 오프라인 대응 | 마지막 응답 캐시를 CoreData에 보관 (`vaccineNameCache`) |
| 주의사항 | 응답 속도 느릴 수 있음 (공공 API 특성). 비동기 처리 + 로딩 상태 필수. API 스펙 변경 시 앱 업데이트 없이 대응하기 어려움 → 번들 폴백 데이터 동시 제공 권장 |

### 2. 건강보험심사평가원 병원정보 서비스

| 항목 | 내용 |
|---|---|
| 목적 | 주변 소아과/약국 정보 조회 |
| 비용 | 무료 (공공데이터포털) |
| 인증 | 공공데이터포털 API 키 발급 필요 |
| 방식 | REST API / XML 또는 JSON |
| 데이터 특성 | 실시간 영업여부 정확도 낮음 (SPEC 3.3 명시) |
| 보완 전략 | 카카오맵 API 병행으로 실시간 영업 확인 + 유저 신고 시스템 |
| 캐싱 전략 | 병원 기본 정보는 로컬 캐시(1일 TTL), 영업여부는 실시간 |
| 주의사항 | 두 API 응답 합성 로직 필요. XML 파서 처리 비용 고려. 데이터 정합성 불일치 케이스 처리 필요 |

### 3. 카카오맵 로컬 API

| 항목 | 내용 |
|---|---|
| 목적 | 키즈카페 등 주변 장소 검색 |
| 비용 | 월 30만 건까지 무료 |
| 인증 | 카카오 디벨로퍼스 앱 키 발급 필요 (REST API 키) |
| 방식 | REST API / JSON |
| 호출 시점 | 주변 탭 진입 시 / 위치 변경 시 |
| 요청 한도 | 월 30만 건은 v1 초기 트래픽에 충분하나, MAU 성장에 따른 한도 모니터링 필요 |
| 주의사항 | 카카오맵 SDK 사용 시 바이너리 크기 증가. REST API만 사용하면 SDK 불필요. 앱 번들에 카카오 설정값 포함 시 환경변수 관리 방식 필요 |

### 4. 복지로 API (참고 — v1에서 경미 사용)

| 항목 | 내용 |
|---|---|
| 목적 | 정부지원금(아동수당·부모급여 등) 정보 |
| 비용 | 무료 (공공데이터포털) |
| 주의사항 | v1 MVP에서는 지원금 정보를 **번들 내 정적 데이터**로 제공하고, API 연동은 v2(가계부 기능)에서 구현하는 것을 권장. 지원금 금액/조건은 정책 변경 빈도가 높아 번들 갱신 주기 관리 필요 |

---

## (e) 구현 난이도 높거나 리스크 있는 부분

### HIGH — 반드시 사전 해결 필요

**1. Pregnancy → Child 승계 전환 플로우**
- 데이터 마이그레이션 + UI 온보딩 + 알림 중단 + 기존 임신 기록 아카이브 처리가 동시에 필요.
- 실패 시 사용자 데이터 손실 위험.
- 상실 케이스(`status = .loss`) 처리 시 모든 예약 알림 즉시 취소 로직이 누락되면 치명적.

**2. CloudKit 가족 공유 충돌 해소**
- 부부가 동시에 같은 DiaryEntry/GrowthRecord를 편집할 경우 Last-Write-Wins 방식이 기본이나, 이는 데이터 손실을 의미.
- 커스텀 conflict resolution policy 또는 merge 전략 필요.
- CloudKit private DB의 zone sharing 설정이 복잡하고 디버깅이 어려움.

**3. 게스트 → 로그인 데이터 마이그레이션**
- SPEC 8.1: 게스트로 기록한 데이터를 가입 후 계정에 연결.
- CoreData의 persistent store를 로컬에서 iCloud로 마이그레이션하는 로직 + 중복 데이터 제거 처리 필요.
- 미처리 시 온보딩 완료율 저하 직결.

**4. 응급 모드 영업 정보 정확도**
- SPEC 3.4: "정보가 틀리면 한 번에 신뢰를 잃는다."
- 심평원 데이터(낮은 정확도) + 카카오맵 데이터 합성 + 유저 신고 반영 로직이 복잡.
- 밤 11시에 잘못된 정보로 부모가 헛걸음하면 1점짜리 리뷰 → 앱 생사 직결.

### MEDIUM — 주의 깊게 설계 필요

**5. WHO 성장 곡선 백분위 계산**
- WHO LMS 파라미터 데이터(성별×연령별 L/M/S 값)를 번들에 포함하고 Box-Cox 변환으로 Z-score → 백분위 변환 필요.
- 데이터 파일 포맷, 보간법, 경계값 처리 등 수학적 구현 필요. 오류 시 잘못된 백분위 표시로 부모 불안 유발.

**6. 사진 타임라인 성능**
- 임신 배 사진 + 아이 성장 사진 통합 타임라인은 수백~수천 장을 다룰 수 있음.
- `LazyVStack` + 썸네일 캐싱 + 페이지네이션 없이는 스크롤 성능 저하.
- `DiaryEntry.photoLocalURLs`의 썸네일을 비동기 생성·캐싱하는 이미지 파이프라인 필요.

**7. 알림 스케줄링과 '기록 멈춤' 모드**
- `UNUserNotificationCenter`에 예약된 접종 알림이 수십 개에 달할 수 있음.
- `Pregnancy.status = .loss` 또는 `paused` 전환 시 관련 알림 전체를 즉시 취소하는 로직이 복잡.
- 앱이 백그라운드 상태일 때도 동작해야 함 → Background Task 설계 필요.

**8. 성장 카드 합성 성능**
- `ImageRenderer`는 메인 스레드 동작 → 고해상도 이미지 합성 시 UI 프리즈 위험.
- `@MainActor` 격리 + Task 분리로 백그라운드 렌더링 후 결과 전달 패턴 설계 필요.

### LOW — 구현 시 주의사항

**9. WidgetKit 업데이트 주기**
- 위젯 타임라인 업데이트가 iOS에 의해 throttle됨. 응급 소아과 위젯은 데이터 신선도 보장이 어려움.
- 위젯 에트리에 "마지막 업데이트 시각" 표시로 신뢰도 문제를 투명하게 처리 권장.

**10. 다국어 문자열 분리 초기 비용**
- Localizable.strings + String Catalog 방식을 처음부터 적용하면 추가 비용이 거의 없으나, 중간에 소급하면 전면 재작업.
- 1일 정도의 초기 셋업 비용을 감수하고 처음부터 `BLCore/StringResources`로 모든 문자열 관리.

---

## (f) 디자인/스펙 확정이 필요한 오픈 질문

### 데이터 모델 관련

**Q1. Pregnancy → Child 승계 시 임신 기록 UI 진입점**
- 아이 프로필 내부에 "태아 시절 보기" 섹션이 있는가?
- 아니면 임신 기록 탭이 별도로 유지되는가?
- 타임라인 혼합 시 배 사진과 성장 사진의 구분 UI는 어떻게 표현하는가?

**Q2. 다태아(쌍둥이) 승계 모델**
- `Pregnancy.fetusCount = 2`인 경우 Child 엔티티가 2개 생성되는가?
- 두 아이 각각에 `pregnancyId`를 동일하게 연결하는가, 아니면 태아별 서브엔티티가 필요한가?

**Q3. 상실 케이스 데이터 영구 보존 범위**
- `Pregnancy.status = .loss` 기록은 Cloud에도 동기화되는가? (가족과 공유 중인 경우)
- 기록 삭제를 선택한 경우 CloudKit에서도 즉시 삭제되는가?

### API 연동 관련

**Q4. 질병관리청 API 장애 시 폴백**
- 번들에 포함할 기본 백신 스케줄 데이터의 최종 버전은 언제 기준으로 번들링할 것인가?
- 번들 데이터와 API 데이터가 불일치할 경우 어느 것을 우선하는가?

**Q5. 카카오맵 API 키 관리**
- REST API 키는 앱 번들에 포함하면 역공학으로 노출됨. 서버에서 중계(proxy)할 것인가, 번들에 직접 포함할 것인가?
- v1 MVP에서는 Supabase 백엔드가 없으므로 초기 처리 방향 확정 필요.

**Q6. 응급 모드 영업 정보 신뢰도 등급 기준**
- SPEC 3.4: "○분 전 확인 + 신뢰도 등급" — 신뢰도 등급의 정의 기준이 필요 (심평원 데이터만 있을 때 vs. 카카오맵 확인 후 vs. 유저 신고 있을 때).

### 아키텍처 관련

**Q7. SPM 모듈 내부 CoreData 스택 소유**
- CoreData persistent container를 `BLData` 패키지에서 단일로 관리할 것인가?
- 아니면 기능 패키지마다 별도 store를 가지는 멀티-스토어 구조인가? (멀티 스토어는 CloudKit 연동이 더 복잡해짐)
- 권장: 단일 `BLData.CoreDataStack` 소유, 기능 패키지는 Repository를 통해서만 접근.

**Q8. 이벤트 버스 구현 방식**
- `NotificationCenter` 기반, Combine `PassthroughSubject`, 또는 Swift Concurrency `AsyncStream` 중 어느 것으로 구현할 것인가?
- 권장: Swift Concurrency `AsyncStream` (iOS 15+, 테스트 용이, 취소 지원).

**Q9. 피처 플래그 서버 구성**
- v1 MVP에서는 Supabase 백엔드 없음. 피처 플래그를 위한 최소한의 원격 구성은 어떻게 구현할 것인가?
- 옵션: Firebase Remote Config (무료), Supabase Edge Functions (v2 이후), 또는 정적 JSON 파일(GitHub Pages/S3)?

### UX/디자인 관련

**Q10. '2탭 완료' 기록 플로우 구체적 동선**
- FAB 탭 → 어느 화면이 먼저 뜨는가? (사진 선택기 바로 뜨는가, 중간 선택 화면이 있는가?)
- 사진 선택 후 자동 저장인가, 저장 버튼이 있는가?

**Q11. 조부모 '심플 뷰' 진입 방법**
- 심플 뷰는 공유 링크로 진입하는가, 앱 내 설정 토글로 전환하는가?
- 별도 Apple ID 없이도 볼 수 있게 할 것인가?

**Q12. 성장 카드 템플릿 수**
- v1에서 제공할 카드 템플릿 디자인 수와 종류가 확정되어야 `ShareCard` 모델의 `templateId` 필드 추가 여부가 결정됨.

**Q13. WHO 성장 곡선 백분위 '안심 톤' 임계값**
- SPEC 14.2: 정성적 안심 메시지를 보여주는 백분위 구간 기준이 필요 (예: 3~97 백분위 = "또래와 비슷하게 잘 크고 있어요").
- 3 미만 또는 97 초과 시 표시할 메시지 톤도 확정 필요.

---

## 종합 요약

v1 MVP(성장기록 + 주변 인프라) 구현을 위한 기술 스택과 데이터 모델은 대체로 준비가 되어 있다. 최대 리스크는 Pregnancy→Child 승계 연속성 보장, CloudKit 충돌 해소, 그리고 응급 모드 영업 정보 정확도 세 가지다. SPM 모듈 분리와 이벤트 버스는 처음부터 구축해야 v2에서 대규모 리팩터링을 방지할 수 있다. 외부 API 세 개는 모두 공개·무료이나 각각 API 키 발급, 데이터 정확도 한계, 월 호출 한도 모니터링이 필요하다.

디자인 파일 수령 전 확정이 필요한 최우선 질문: Q1(임신→아이 타임라인 혼합 UI), Q5(카카오맵 API 키 관리), Q7(CoreData 스택 소유 구조).
