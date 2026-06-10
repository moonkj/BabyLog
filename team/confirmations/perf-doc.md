# BabyLog — Perf/Doc 확인 보고서 (Phase 0)

> Teammate 4 (perf-doc) 작성 | 2026-06-10  
> Phase 0: 코드 작성 금지. 스펙 정독 후 관점 정리만.

---

## (a) 성능 핫스팟 사전 식별

### 핫스팟 1 — 사진 타임라인 리스트 스크롤 (최우선)

**위험도: 최고**

사진 타임라인(기능 2)은 앱의 핵심 리텐션 기능이다. 유저당 누적 사진이 수백~수천 장에 달할 수 있고, 임신 사진(기능 1)과 성장 사진이 연속으로 이어지는 구조상 리스트 길이가 상당하다.

**예상 병목:**
- `LazyVStack` + `AsyncImage` 조합 시 스크롤 중 썸네일 on-demand 디코딩 → 프레임 드롭
- 풀사이즈 이미지를 썸네일 크기 셀에 그대로 로드하면 메모리 급등
- EXIF 날짜 파싱을 UI 스레드에서 수행하면 첫 렌더 지연
- 배 사진(임신) → 성장 사진 연속 뷰에서 날짜 기준 재정렬 비용

**사전 설계 방침 (구현 시 적용):**
- 저장 시점에 썸네일(200×200px 이하) 미리 생성, CoreData 별도 attribute에 저장
- `ImageRenderer` 또는 `UIGraphicsImageRenderer`로 다운샘플링 후 캐시 (NSCache + 디스크 이중)
- 썸네일 디코딩은 반드시 백그라운드 큐 (`Task { await }` + actor 분리)
- `LazyVStack` 내 셀당 `id`는 `DiaryEntry.id` (UUID) 고정 → 불필요 diff 방지

---

### 핫스팟 2 — 성장 카드 합성 (ImageRenderer + Core Graphics)

**위험도: 높음**

기능 2.4의 성장 카드 공유는 바이럴 핵심 기능이다. 아이 사진 위에 데이터를 오버레이해 4:5 / 1:1 / 9:16 세 가지 비율로 내보낸다.

**예상 병목:**
- `ImageRenderer`는 메인 스레드에서 실행되므로 고해상도 이미지 합성 시 UI 블로킹
- 9:16 스토리 비율은 픽셀 버퍼가 피드 대비 약 2.4× → 메모리 스파이크
- 블러(얼굴 가리기 옵션) + 그라데이션 스크림 + 텍스트 오버레이 복합 연산
- 사용자가 위치·필드를 조정할 때마다 실시간 미리보기 재합성 요구

**사전 설계 방침:**
- `ImageRenderer` 캡처는 `DispatchQueue.global(qos: .userInitiated)`에서 실행 후 main으로 결과 전달
- 미리보기는 다운스케일(50%) 래스터라이즈 → 확정 시에만 풀 해상도 합성
- 블러는 `CIFilter.gaussianBlur()` + `CIContext(options: [.useSoftwareRenderer: false])` (GPU 가속)
- 템플릿 레이아웃을 데이터 모델로 분리하는 스펙 방침 유지 (향후 템플릿 추가 시 재합성 로직 재사용)

---

### 핫스팟 3 — Swift Charts 성장 곡선 렌더링

**위험도: 중-높음**

기능 2(성장 차트)와 기능 1(체중 추이 차트)은 WHO 성장 곡선 오버레이를 포함한다. 다자녀(최대 5명) 전환 시 각 차트 재빌드가 발생한다.

**예상 병목:**
- WHO 데이터셋 전체 포인트를 매번 `Chart` 뷰에 주입하면 SwiftUI diff 비용 증가
- 다자녀 전환 탭 + 기간 필터 변경마다 `GrowthRecord` 전체 fetch → 리렌더
- `@Published` 상태가 상위 뷰에 있으면 무관한 뷰까지 리빌드

**사전 설계 방침:**
- WHO 곡선 포인트는 앱 번들 JSON에서 로드 후 `@State` 또는 앱 시작 시 싱글톤 캐시
- CoreData fetch는 `NSFetchedResultsController` 또는 `@FetchRequest` + predicate 범위 제한 (childId + date 인덱스 필수)
- 차트 뷰를 독립 `@StateObject` ViewModel로 격리해 상위 뷰 리빌드 전파 차단

---

### 핫스팟 4 — CloudKit 동기화 부하

**위험도: 중**

가족 공유(부부 최대 6명, 기능 1·2)는 CloudKit 기반이다. 성장 기록, 사진 메타데이터, 다자녀 프로필이 동기화 대상이다.

**예상 병목:**
- 기록 저장 즉시 CloudKit push → 사진 다중 업로드 시 네트워크 burst
- CloudKit 동기화 완료 전 UI 낙관적 업데이트(Optimistic UI) 미적용 시 응답 지연 체감
- 오프라인 기록 후 동기화 재개 시 merge conflict (동일 날짜 기록 중복 가능성)
- `NSPersistentCloudKitContainer` 자동 동기화가 백그라운드 배터리 사용에 영향

**사전 설계 방침:**
- 로컬 CoreData를 source of truth로, CloudKit은 eventual consistency 수용
- 사진 asset은 메타데이터만 CloudKit 동기화, 실제 이미지는 로컬/iCloud Photos (CLAUDE.md 절대 원칙)
- `syncStatus` 상태를 UI에 경량 표시 (동기화 중 인디케이터)
- merge policy: `NSMergeByPropertyObjectTrumpMergePolicy` 적용 + 날짜 기반 우선 전략 사전 결정 필요

---

### 핫스팟 5 — 외부 API 호출 (주변 인프라, 기능 3)

**위험도: 중**

건강보험심사평가원 + 카카오맵 로컬 API + 복지로 API를 실시간 호출한다. 응급 모드는 빠른 응답이 핵심 UX 요구사항이다.

**예상 병목:**
- 응급 모드 진입 시 복수 API 동시 호출 → 느린 공공 API 응답 시 빈 화면 노출
- 검색 필터 변경마다 API 재호출 → 과호출로 무료 할당량 소진 (카카오 월 30만건)
- 위치 권한 없을 때 fallback 없으면 탭 전체 비활성화 risk

**사전 설계 방침:**
- 디바운싱: 검색어·필터 변경 후 300~500ms 디바운스 (`Task { try await Task.sleep(…) }` 패턴)
- 페이지네이션: 리스트 결과를 페이지 단위(20개)로 로드, 스크롤 끝 도달 시 다음 페이지
- 응답 캐시: 병원·약국 데이터는 TTL 1시간 메모리 캐시 + 로컬 디스크 캐시 (공공 API는 실시간성 낮음)
- 응급 모드: 가장 최근 캐시된 데이터 우선 즉시 표시 → 백그라운드 갱신 (stale-while-revalidate)
- 카카오맵 호출량 모니터링 + 월 할당량 경보 임계값 설정 (예: 25만건 도달 시 알림)

---

## (b) SwiftUI 리빌드 최소화 패턴 방침

### 상태 범위 최소화 원칙

| 안티패턴 | 권장 패턴 |
|---|---|
| 최상위 뷰에 `@Published var allEntries` | 뷰별 독립 `@StateObject` ViewModel |
| 사진 URL을 `@State`로 전달 | `EquatableView` 또는 `id` 안정화 |
| 타임라인 전체 배열 `@ObservedObject` | `@FetchRequest` + predicate 범위 제한 |
| 다자녀 전환 시 전체 탭 리빌드 | 아이 선택 상태만 분리된 `@EnvironmentObject` |

### 이미지 다운샘플링 방침

```
저장 시점 → 썸네일(200px) 생성 → CoreData 별도 저장
화면 표시 → 썸네일 우선 로드 → 풀사이즈는 상세 뷰 진입 시만
AsyncImage 사용 금지 (캐시 없음) → 자체 캐시 레이어 필수
```

- `UIImage(data:scale:)` + `UIGraphicsImageRenderer`로 다운샘플링
- `NSCache<NSString, UIImage>` 메모리 캐시 + FileManager 디스크 캐시 병행
- 메모리 경고(`UIApplication.didReceiveMemoryWarningNotification`) 시 캐시 퍼지

### @StateObject 경계 설계

- `GrowthChartViewModel`: 차트 데이터 소유 (독립 수명)
- `TimelineViewModel`: 타임라인 엔트리 + 페이징 소유
- `ShareCardViewModel`: 카드 합성 상태 소유
- 부모→자식 데이터 전달은 `let` 프로퍼티 + `Equatable` 준수로 불필요 diff 차단

### 배터리 고려 — WidgetKit 갱신 주기 최적화

| 위젯 종류 | 권장 갱신 전략 |
|---|---|
| 오늘의 할 일 (접종·지원금) | `TimelineReloadPolicy.atEnd` + 자정 1회 갱신 |
| 아이 요약 (사진·월령) | 사용자 기록 저장 이벤트 시 `WidgetCenter.shared.reloadTimelines()` 트리거 |
| 주변 응급 (소아과 영업여부) | `.after(Date(timeIntervalSinceNow: 3600))` 1시간 주기, 야간 주기 단축 금지 |

- 위젯에서 네트워크 직접 호출 금지 → 앱 포그라운드 진입 시 캐시 갱신, 위젯은 캐시 읽기만
- App Group + UserDefaults(`suite:`) 공유로 앱↔위젯 데이터 전달

---

## (c) 문서 구조 제안

아래 구조는 향후 README 또는 Notion에 복사·붙여넣기 가능한 형태로 제안한다. Phase 0에서는 구조만 정의하며, 실제 내용은 구현 진행에 따라 채운다.

---

### README.md (루트)

```markdown
# BabyLog

육아 슈퍼앱 — 임신부터 육아까지, 우리 동네 육아의 모든 것

## 빠른 시작
- 요구 환경: Xcode 15+, iOS 16+, Swift 5.9+
- 설정: [빌드·설정 가이드](docs/setup.md) 참조
- 스펙: [SPEC.md](SPEC.md) | 아키텍처 원칙: [CLAUDE.md](CLAUDE.md)

## 모듈 구조
[모듈 목록 및 SPM 패키지 구조]

## 외부 API 키 설정
[docs/api-keys.md 참조]

## 팀 협업
[team/TEAM.md 참조]
```

---

### docs/ 폴더 구조 제안

```
docs/
├── setup.md             # 빌드·설정 방법
├── architecture.md      # 모듈 구조·이벤트 버스·SPM 패키지 목록
├── data-model.md        # 전체 Entity 목록·관계도·CoreData 스키마
├── api-guide.md         # 외부 API 연동 가이드 (키 발급·호출 규칙·에러 처리)
├── perf-guide.md        # 성능 패턴 가이드 (이미지 캐싱·LazyVStack·Charts 최적화)
└── privacy-policy.md    # 데이터 처리 방침 (앱스토어 제출용 초안)
```

---

### docs/setup.md — 빌드·설정 방법 (초안 구조)

```markdown
## 요구 환경
- Xcode 15.x 이상
- iOS 16.0+ 배포 타겟
- Swift 5.9+
- CocoaPods 불사용 (SPM 전용)

## 초기 설정
1. 저장소 클론
2. `Config/Secrets.xcconfig` 생성 (아래 키 필요)
3. 시뮬레이터 또는 실기기 빌드

## 필수 API 키 (Secrets.xcconfig)
| 키 이름 | 발급처 | 무료 한도 |
|---|---|---|
| KAKAO_MAP_API_KEY | Kakao Developers | 월 30만건 |
| HIRA_API_KEY | 공공데이터포털 | 무료 |
| VACCINE_API_KEY | 질병관리청 예방접종도우미 | 무료 |
| WELFARE_API_KEY | 복지로 | 무료 |

## CloudKit 설정
- [CloudKit Dashboard 링크 및 컨테이너 ID 명시]
- CKContainer.default() 사용 설정 방법

## Supabase 설정 (v2 마켓 이후)
- .env 파일 또는 Secrets.xcconfig에 SUPABASE_URL, SUPABASE_ANON_KEY 추가
```

---

### docs/architecture.md — 모듈 구조 (초안 구조)

```markdown
## SPM 패키지 목록

| 패키지명 | 책임 영역 | 의존성 |
|---|---|---|
| BabyCore | 공통 모델, 이벤트 버스, CoreData 스택 | - |
| BabyGrowth | 기능 1·2 (임신·성장 기록) | BabyCore |
| BabyInfra | 기능 3 (주변 인프라·응급) | BabyCore |
| BabyMarket | 기능 4 (중고 마켓, v2) | BabyCore |
| BabyFinance | 기능 5 (가계부, v2) | BabyCore |
| BabyCrew | 기능 6 (동네 크루, v3) | BabyCore |
| BabyWidget | WidgetKit 위젯 | BabyCore |
| BabyShared | 공통 UI 컴포넌트, 디자인 시스템 | - |

## 이벤트 버스 (공통 채널)
- 이정표 달성 → 마켓 추천 트리거
- 성장 기록 저장 → 위젯 갱신 트리거
- 예방접종 완료 → 뱃지 부여 트리거
[이벤트 명세 테이블 — 구현 확정 후 채움]
```

---

### docs/data-model.md — 데이터 모델 문서 (초안 구조)

SPEC.md의 데이터 구조 섹션을 단일 레퍼런스 문서로 통합한다.

```markdown
## Entity 전체 목록

### 임신·성장 기록 (CoreData + CloudKit)
- Pregnancy, MaternalRecord, FetalMovement, PrenatalCheckup
- Child, GrowthRecord, DiaryEntry, VaccineRecord, AdvancedLog, ShareCard

### 가계부 (CoreData + CloudKit)
- Expense, RecurringExpense, Subsidy

### 마켓·커뮤니티 (Supabase, v2+)
- [v2 구현 시 추가]

### 뱃지·신뢰도 (Supabase, v2+)
- Badge, UserBadge, UserTier, BadgeEvent

## CoreData 인덱스 설계 원칙
- GrowthRecord: (childId + date) 복합 인덱스 필수
- DiaryEntry: (childId + date + recordType) 인덱스
- Expense: (childId + date + category) 인덱스

## 임신→아이 전환 로직
[Pregnancy → Child 승계 시 데이터 이전 시퀀스]

## 데이터 익스포트 포맷
[JSON 표준 포맷 명세 — 데이터 주권 원칙 구현]
```

---

### docs/api-guide.md — 외부 API 연동 가이드 (초안 구조)

```markdown
## 공통 원칙
- 모든 API 키는 Secrets.xcconfig 관리 (Git 미커밋)
- 응답 캐시 기본 TTL: 병원·약국 1시간, 복지로 지원금 24시간
- 공공 API 에러 시 캐시 fallback 필수 (서비스 다운 대비)

## 1. 질병관리청 예방접종도우미
- 용도: 월령별 예방접종 스케줄 자동 생성
- 호출 시점: 아이 프로필 등록 시 1회 + 월령 변경 시
- 캐시 전략: 로컬 번들 내장 기본 스케줄 + API 최신화

## 2. 건강보험심사평가원 (HIRA)
- 용도: 소아과·약국 정보
- 한계: 실시간 영업여부 정확도 낮음 → 카카오맵 병행
- 페이지네이션: numOfRows=20, pageNo 증가 방식

## 3. 카카오맵 로컬 API
- 용도: 키즈카페·주변 장소 검색
- 무료 한도: 월 30만건 (모니터링 필수)
- 디바운싱: 필터 변경 후 300ms 지연 호출

## 4. 복지로 API
- 용도: 아동수당·부모급여·첫만남이용권 등 지원금 정보
- 호출 시점: 아이 월령 도달 이벤트 시
- 캐시 전략: 24시간 디스크 캐시 (지원금 정책은 자주 변경되지 않음)

## 5. KATSA/KERI 리콜 DB
- 용도: 카시트 등 리콜 조회 (기능 4 마켓)
- 갱신 주기: 서버 월 1회 갱신, 클라이언트는 서버 캐시 사용
```

---

## (d) 디자인·스펙 확정이 필요한 오픈 질문

### 성능·구현 관련 오픈 질문

| # | 질문 | 관련 기능 | 우선순위 |
|---|---|---|---|
| P-1 | 타임라인 썸네일 크기 기준은? (100px / 200px / 300px) — 저장 비용 vs 화질 트레이드오프 결정 필요 | 기능 1·2 | 최고 |
| P-2 | 사진 무료 저장 '200장/월' 한도를 초과한 사진의 처리 방침은? (업로드 거부 vs 로컬만 저장 vs 압축 저장) | 기능 2 | 높음 |
| P-3 | CloudKit 동기화 conflict 해결 정책: 최신 기록 우선 vs 디바이스 우선 vs 사용자 수동 선택? | 기능 1·2 | 높음 |
| P-4 | 성장 카드 합성 시 풀 해상도 기준은? (3×레티나 기준 최대 픽셀 수 확정) — 메모리 예산 결정에 직결 | 기능 2.4 | 높음 |
| P-5 | 응급 모드 API 타임아웃 허용 기준은? (사용자가 몇 초까지 기다릴 수 있는가) — UX 기준 확정 필요 | 기능 3 | 높음 |
| P-6 | WHO 성장 곡선 데이터셋 내 번들 포함 방식 vs 서버 갱신 방식? (WHO 데이터 업데이트 주기 고려) | 기능 2 | 중 |
| P-7 | WidgetKit '주변 응급' 위젯의 위치 정보 갱신 방식: 위젯 자체 위치 접근 vs 앱이 업데이트? (iOS 제약 확인 필요) | 기능 3·10 | 중 |
| P-8 | 카카오맵 월 30만건 한도 초과 시 fallback 전략: 캐시 표시 only vs HIRA API only vs 기능 비활성화? | 기능 3 | 중 |
| P-9 | `NSPersistentCloudKitContainer` 자동 동기화 범위 제한 정책: 어떤 Entity를 동기화 대상에서 제외할지? (비용·프라이버시) | 전체 | 중 |
| P-10 | 다자녀(5명) 동시 성장 차트 표시 옵션 제공 여부? (한 화면에 비교 vs 탭 전환만) — 차트 복잡도에 직결 | 기능 2 | 중 |

### 문서화·아키텍처 관련 오픈 질문

| # | 질문 | 관련 영역 | 우선순위 |
|---|---|---|---|
| D-1 | SPM 패키지 경계 최종 결정: 기능별 1패키지 vs 레이어별(Data/Domain/UI) 분리 vs 혼합? — 팀장(아키텍트) 결정 필요 | 전체 아키텍처 | 최고 |
| D-2 | 이벤트 버스 구현체 선택: Swift Concurrency `AsyncStream` vs Combine `PassthroughSubject` vs 커스텀 버스? | 부록 B | 높음 |
| D-3 | 데이터 익스포트 표준 포맷 명세: JSON 스키마 버전 관리 방식과 포함 범위(사진 포함 여부)? | 기능 14 | 높음 |
| D-4 | Secrets.xcconfig vs .env vs 환경변수 방식 중 API 키 관리 방식 최종 결정 (CI/CD 파이프라인 연계) | 빌드 설정 | 중 |
| D-5 | Supabase 테이블 스키마는 누가 언제 확정하는가? (v2 마켓 개발 시작 전 결정 필요) | 기능 4·5 | 중 |
| D-6 | 다국어 문자열 관리 도구: Xcode `.strings` 파일 vs `swift-gen` vs 외부 서비스(Lokalise 등)? | 전체 | 중 |

### 디자인 확정 대기 중인 항목 (디자인 파일 수신 후 결정)

| # | 항목 | 영향 범위 |
|---|---|---|
| DS-1 | 타임라인 셀 레이아웃: 사진 크기·여백·텍스트 계층 확정 → 썸네일 사이즈 결정 연동 | 기능 1·2 |
| DS-2 | 성장 카드 템플릿 디자인 확정 → `ImageRenderer` 레이아웃 코드 작성 가능 시점 | 기능 2.4 |
| DS-3 | 응급 모드 전용 다크 레이아웃 디자인 → 일반 UI와 별도 View 분기 여부 결정 | 기능 3 |
| DS-4 | 뱃지 아이콘 에셋 확정 → 색약 대응 3중 인코딩(색+아이콘+레이블) 구현 가능 시점 | 기능 7 |
| DS-5 | Swift Charts 커스텀 스타일링 범위 확정 → WHO 성장 곡선 오버레이 표현 방식 | 기능 2 |
| DS-6 | Dynamic Type 폰트 스케일 기준 확정 → 조부모 심플 뷰 글씨 크기 분기 | 기능 12 |

---

## 요약: Perf/Doc 관점 우선순위

### 최우선 처리 (구현 착수 전 결정 필수)

1. **썸네일 저장 전략** (P-1) — 코드 한 줄도 쓰기 전에 결정해야 할 아키텍처 선택
2. **SPM 패키지 경계** (D-1) — 팀장(아키텍트)과 공동 결정
3. **CloudKit conflict 정책** (P-3) — 데이터 무결성 직결

### 성능 보증을 위한 사전 준비물

- 이미지 캐시 레이어 설계서 (구현 전 리뷰)
- CoreData 인덱스 설계 목록
- API 호출 할당량 모니터링 대시보드 (카카오맵 30만건 한도)

### 문서 작성 착수 시점

| 문서 | 작성 착수 조건 |
|---|---|
| docs/setup.md | Xcode 프로젝트 생성 후 즉시 |
| docs/architecture.md | SPM 패키지 구조 확정 후 |
| docs/data-model.md | CoreData 스키마 1차 확정 후 |
| docs/api-guide.md | 외부 API 키 발급 후 |
| docs/perf-guide.md | MVP 성능 테스트 후 패턴 추출 |

---

*이 문서는 Phase 0 확인 단계 산출물이다. 코드 작성 없이 스펙 분석만 수행했다.*  
*디자인 파일 수신 후 DS-1~DS-6 항목을 업데이트한다.*
