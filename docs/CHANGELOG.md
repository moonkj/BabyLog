# BabyLog 변경 이력 (CHANGELOG)

> 마지막 갱신: 2026-06-10  
> 입력 기준: `process.md` 실행 로그 + `Tasklist.md` 라운드 보드  
> git log 미참조 — process.md 단일 소스 기준

---

## 현재 앱 상태 요약

| 항목 | 현황 |
|---|---|
| **화면** | 5탭 전부 실화면 완성 (홈·기록·동네·가계부·내정보) |
| **테스트** | 214개+ (라운드 10 완료 기준, PASS 100% 유지) |
| **커밋** | main 브랜치 지속 증가 |
| **실기기** | iPhone "Moon" (iOS 26.5.1) 설치·실행 확인 (위젯 포함) |
| **디자인** | 화이트 `#FFFFFF` + 딥 인디고 `#1A1B2E` + 앤티크 골드 `#C9A961` (TickLab 참고 프리미엄) |
| **디스플레이 모드** | 라이트 모드 고정 (`UIUserInterfaceStyle=Light`) |
| **프레임워크** | Swift/SwiftUI (iOS 26 Liquid Glass 네이티브) |
| **WidgetKit** | 오늘 할 일·아이 요약·주변 소아과 3종 위젯 완성 (라운드 7 완료) |
| **네트워킹 인프라** | `APIClient` + `APIConfig` + `ProviderFactory` + Live/Mock 폴백 + 응답 파서 (라운드 8~11) |
| **UX 컴포넌트** | 빈상태·Skeleton 로딩·에러 핸들링 컴포넌트 전 탭 적용 (라운드 8, 라운드 11 확장) |
| **지도** | Apple MapKit 네이티브 (키 불필요) + 카카오 로컬 검색 (REST 키 입력 시 자동 Live 전환) |

### 키 발급 안내

카카오 REST API 키: [developers.kakao.com](https://developers.kakao.com) 에서 발급 → `Info.plist`의 `KAKAO_REST_API_KEY`에 입력하면 병원 POI 검색이 자동으로 Live 모드로 전환됩니다.

### 남은 백로그 (v1 → v2 이후)

- **API 실키 입력** — 카카오 REST 키 입력 후 Live POI 검색 완전 활성화
- **CloudKit 가족공유** — Codable → CoreData 마이그레이션 + CloudKit 동기화 (가족 계정 공유)
- **App Group 위젯 실데이터** — WidgetKit 타깃과 앱 간 App Group 컨테이너 공유 실영속화
- **SPM 모듈화** — BLCore·BLData·BLGrowth 등 패키지 분리
- **다크 모드 재정비** — 인디고·골드 팔레트 기반 다크 토큰 전면 재조정

---

## 라운드 11 — Apple MapKit 지도·ProviderFactory 외부 API 배선 (완료 · 2026-06-10)

> **테스트**: 214개+ → 갱신 예정 (ProviderFactory/APIConfig Mock 폴백 테스트 추가)

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `Features/Dongne/NearbyScreen.swift` | **Apple MapKit 지도 뷰** — 네이티브 `Map` 컴포넌트, API 키 불필요. 현재 위치 중심 표시·병원 핀 오버레이. ProviderFactory를 통해 병원 데이터(심평원/카카오 로컬) 조회. |
| `Networking/ProviderFactory.swift` | **외부 API ProviderFactory** — 병원(심평원 + 카카오 로컬 검색)·지원금(복지로)·예방접종(질병청) 3종 프로바이더 팩토리. `KAKAO_REST_API_KEY` 유무 자동 감지 → 키 있으면 Live, 없으면 Mock 자동 폴백. |
| `Networking/HospitalProvider.swift` | 병원 프로바이더 — 심평원 기관 API + 카카오 로컬 검색 결합. 키 미입력 시 Mock 병원 데이터 반환. |
| `Networking/SubsidyProvider.swift` | 지원금 프로바이더 — 복지로 정부지원금 조회 API 배선. 키 미입력 시 Mock 데이터 폴백. |
| `Networking/VaccineProvider.swift` | 예방접종 프로바이더 — 질병청 예방접종 도우미 API 배선. 키 미입력 시 Mock 스케줄 반환. |
| `Features/Budget/BudgetScreen.swift` | 지원금 화면에 `SubsidyProvider` 연결 — 복지로 실데이터 조회 또는 Mock 자동 폴백. Skeleton 로딩·빈상태·에러 상태 적용. |
| `Features/Record/RecordScreen.swift` | 예방접종 세그먼트에 `VaccineProvider` 연결 — 질병청 실데이터 또는 Mock 스케줄. Skeleton 로딩·빈상태·에러 상태 적용. |
| `Components/SkeletonView.swift` (확장) | 동네·가계부·기록 탭 외부 API 로딩 구간에 Skeleton shimmer 전면 적용. |
| `Tests/ProviderFactoryTests.swift` | ProviderFactory Mock 폴백 동작 검증 — 키 없음 → Mock 반환, 에러 → 폴백 경로 확인. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **Apple MapKit 지도** | 주변 탭 `NearbyScreen`에 네이티브 `Map` 뷰 통합. iOS 17+ `MapKit` 프레임워크, 별도 API 키 불필요. 위치 권한 요청·현재 위치 중심 초기화·병원 어노테이션 핀 오버레이. |
| **ProviderFactory 3종 배선** | 병원(심평원+카카오 로컬), 지원금(복지로), 예방접종(질병청) 프로바이더를 각 화면에 실제 연결. `APIConfig`의 `KAKAO_REST_API_KEY` 값 유무를 런타임에 감지해 Live/Mock 자동 전환. |
| **Mock 자동 폴백** | 카카오 REST 키 미입력 상태에서도 앱 전 기능 정상 동작. 실키 입력 즉시 Live 전환 (재빌드 불필요). |
| **Skeleton/빈상태/에러 전면 확장** | 외부 API를 사용하는 동네·가계부·기록 탭 전 구간에 Skeleton 로딩, BLEmptyState 빈상태, ErrorStateView 에러 처리 적용. |

### 팀장 통합 완료

- `NearbyScreen` MapKit 지도 + ProviderFactory 병원 조회 연결
- `BudgetScreen` SubsidyProvider (복지로) + `RecordScreen` VaccineProvider (질병청) 배선
- ProviderFactory Mock 폴백 테스트 PASS 확인
- Skeleton·빈상태·에러 컴포넌트 외부 API 구간 전체 삽입

---

## 라운드 10 — 앱 아이콘·런치스크린·실데이터 CRUD (완료 · 2026-06-10)

> **테스트**: 198개 → **214개** (+16, 기록 CRUD·하위호환·영속화 테스트)

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `Assets.xcassets/AppIcon` | **앱 아이콘** — 세이지+골드 on 크림 배경, 1024 Asset Catalog (알파 채널 제거). 커밋 9107edb. |
| `Info.plist` + `Assets` | **런치스크린** — 로고 + 크림(`#FAFAF7`) 배경. 흰 플래시 제거, 브랜드 스플래시 적용. |
| `Data/AppStore.swift` | **실데이터 CRUD 확장** — `growthRecords`·`diaryEntries` 배열, `addDiaryEntry`·`addGrowthRecord`·`diaryEntries(for:)`·`growthRecords(for:)`. `PersistableState` 하위호환 디코딩 보장. |
| `Features/QuickRecord/QuickRecordSheet.swift` | 빠른기록 시트 완성 → 선택 아이에 실제 저장(`addDiaryEntry`/`addGrowthRecord`). 보상 애니메이션 유지. |
| `Features/Record/RecordScreen.swift` | 타임라인·성장차트(Swift Charts WHO밴드)가 `store` 실기록 표시. 기록 없음 → `BLEmptyState` 권유 톤. |
| `Features/Profile/ProfileScreen.swift` | 내정보 데이터 내보내기 → `AppStore` 연결, 실데이터 기반 JSON 내보내기. |
| `Tests/` | 기록 CRUD·하위호환 디코딩·영속화 16 테스트 추가. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **앱 아이콘 + 런치스크린** | 세이지+골드 on 크림 아이콘과 브랜드 스플래시로 앱 첫인상 완성. 알파 채널 제거로 App Store 검수 규격 준수. |
| **기록 CRUD 실데이터화** | 빠른기록 저장 → AppStore 반영 → RecordScreen 타임라인·성장차트 실시간 표시 → 앱 재실행 후에도 Codable 영속화로 유지되는 end-to-end 흐름 완성. |
| **하위호환 디코딩** | `PersistableState` 구버전 JSON 자동 디코딩. 앱 업데이트 시 기존 사용자 데이터 손실 없음. |

### 팀장 통합 완료

- AppStore CRUD API + 영속화 하위호환 적용
- 빠른기록 → RecordScreen 실시간 반영 흐름 검증
- iPhone 재설치·실행 완료
- 전체 build+test **214/214 PASS** 확인

---

## 라운드 9 — 앱 실데이터 백본 (완료 · 2026-06-10)

> **테스트**: 180개 → **198개** (+18, AppStore 온보딩/선택/영속화 테스트)

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `Data/AppStore.swift` | **AppStore API 확장** — `selectedChild`·`activePregnancy`·`hasContent`·`completeBabyOnboarding(name:birthDate:gender:)`·`startPregnancy(lmp:edd:nickname:)`·`selectedChildId`. |
| `BabyLogApp.swift` | `@StateObject AppStore(persistence:)` 생성 + `.environmentObject` 주입 + `enableAutoPersist()` 앱 시작 시 자동연결. |
| `Shell/MainTabView.swift` | 온보딩 게이트 — `onboarded || store.hasContent` 조건으로 탭 진입 제어. |
| `Features/Onboarding/OnboardingView.swift` | 온보딩 완료 → `completeBabyOnboarding`/`startPregnancy`로 AppStore에 실기록 저장. |
| `Features/Home/HomeScreen.swift` | `store.children`(다자녀 칩)·`selectedChild`·`activePregnancy`로 이름·D+일·월령·주수 실표시. 폴백 처리 포함. |
| `Features/Home/PregnancyHomeView.swift` | `activePregnancy` 실데이터로 주수·D-day·닉네임 표시. |
| `Tests/` | AppStore 온보딩/선택/영속화 18 테스트 추가. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **온보딩 → 실데이터 흐름 완성** | 온보딩 입력값 → `AppStore`(Codable 디스크 영속화) → 홈이 실제 입력한 아이 표시. 앱 재실행 후에도 데이터 유지. |
| **AppStore 전역 주입** | `BabyLogApp`에서 단일 `@StateObject`로 생성, 전 화면에 `@EnvironmentObject`로 전달. |
| **다자녀 지원** | `store.children` 배열 + `selectedChildId`로 탭 상단 아이 칩 전환 지원. |

### 팀장 통합 완료

- AppStore API + 앱 주입 + 온보딩 게이트 연결
- 홈·임신홈 실데이터 바인딩 검증
- 전체 build+test **198/198 PASS** 확인
- ⚠️ iPhone 재설치: 기기 연결 끊김으로 보류 (라운드 10에서 완료)

---

## 라운드 8 — 홈 레이아웃 3안·빈상태/로딩/에러 UX·네트워킹 인프라 (완료 · 2026-06-10)

> **테스트**: 171개 → 171개+ (네트워킹·UX 컴포넌트 테스트 추가)

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `Features/Home/HomeLayoutOption.swift` | **홈 레이아웃 3안** 정의 및 선택 로직 — ①히어로(대형 우선순위 카드 중심), ②대시보드(6종 요약 타일 그리드), ③타임라인(최근 기록 세로 스트림) |
| `Features/Home/HomeHeroLayout.swift` | 히어로 레이아웃 구현 — PriorityEngine 최상위 1건을 풀폭 히어로 카드로 강조 |
| `Features/Home/HomeDashboardLayout.swift` | 대시보드 레이아웃 구현 — 아이 월령·예방접종·지원금·기록 요약·날씨 등 6종 타일 2열 그리드 |
| `Features/Home/HomeTimelineLayout.swift` | 타임라인 레이아웃 구현 — 최근 기록(사진+메모) 세로 피드, 빠른 기록 진입 FAB와 통합 |
| `Components/EmptyStateView.swift` | **빈상태 컴포넌트** — 이미지·제목·설명·CTA 버튼 조합. 탭별 맥락 메시지 주입 지원. 기대감 UI(설레는 첫 기록 유도 문구). |
| `Components/SkeletonView.swift` | **Skeleton 로딩 컴포넌트** — shimmer 애니메이션 적용 카드·리스트·타일 플레이스홀더. `@Environment(\.accessibilityReduceMotion)` 자동 대응. |
| `Components/ErrorStateView.swift` | **에러 핸들링 컴포넌트** — 네트워크·데이터 에러 유형별 아이콘·메시지·재시도 버튼. Live/Mock 폴백 전환 시 UI 연속성 유지. |
| `Networking/APIClient.swift` | **APIClient** — async/await 기반 범용 HTTP 클라이언트. `URLSession` 래퍼, 타임아웃·재시도 정책 내장. 테스트 주입 가능(`APIClientProtocol`). |
| `Networking/APIConfig.swift` | **APIConfig** — 외부 API 엔드포인트·키·헤더 중앙 관리. 질병청·카카오맵·심평원·복지로 설정 분리. 실키 미입력 시 자동 Mock 폴백. |
| `Networking/LiveAPIProvider.swift` | **Live 프로바이더** — 실키 환경변수 검출 시 실제 외부 API 호출 경로 활성화. |
| `Networking/MockAPIProvider.swift` | **Mock 프로바이더** — 실키 미설정 시 자동 선택. 기존 라운드 4 Mock 스텁을 APIClient 계약으로 업그레이드. |
| `Networking/APIResponseParser.swift` | **응답 파서** — JSONDecoder 래퍼. 외부 API별 응답 모델 디코딩·에러 변환·빈응답 처리 통합. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **홈 레이아웃 3안** | 히어로·대시보드·타임라인 3가지 레이아웃을 사용자가 선택하거나 아이 월령에 따라 자동 추천. `AppStorage` 기반 선택 영속화. |
| **기대감 UX 컴포넌트** | 빈상태(EmptyState)·Skeleton 로딩·에러 상태 3종 컴포넌트를 전 탭·전 화면에 통일 적용. 데이터 없음/로딩 중/에러 각 상태에서 사용자 이탈 방지 UX. |
| **네트워킹 인프라 재정비** | 라운드 4의 임시 Mock 스텁을 `APIClient`+`APIConfig`+파서 아키텍처로 격상. Live/Mock 폴백 자동 전환으로 실키 없이도 앱 전 기능 동작. |
| **과학적 토론(해소)** | `APIClientProtocol` 격리 → QA Mock 주입 시 URLSession 실호출 0건 보장. SkeletonView `frame` 고정 vs 동적 — 동적(`GeometryReader`) 채택으로 다양한 화면 크기 대응. |

### 팀장 통합 완료

- `HomeScreen.swift` 레이아웃 스위처(히어로/대시보드/타임라인) 연결 + `AppStorage` 영속화
- EmptyStateView / SkeletonView / ErrorStateView 전 탭 진입점 일괄 삽입
- `APIClient` + `APIConfig` → 기존 `Networking/` 스텁 교체, Live/Mock 자동 폴백 동작 확인
- 전체 build+test PASS 확인 + iPhone 재설치

---

## 라운드 7 — TickLab 프리미엄 색상·엔진 UI 연결·실사진·WidgetKit (완료 · 2026-06-10)

> **테스트**: 171개 전량 통과 (PASS 100%) · iPhone 위젯 포함 설치 확인

### 산출물

| 파일 / 항목 | 내용 |
|---|---|
| `DesignSystem/AppColors.swift` 外 전 화면 | **TickLab 참고 프리미엄 색상** — 배경 화이트 `#FFFFFF` + 딥 인디고 `#1A1B2E` + 앤티크 골드 `#C9A961`. 토큰 이름 유지로 전 화면 자동 반영. |
| `Features/Home/HomeScreen.swift` | `PriorityEngine` → 홈 "지금 가장 중요한 것" 카드 와이어링 완료. 엔진 출력(`PriorityItem`)을 카드 UI에 바인딩. |
| `Features/Profile/ProfileScreen.swift` | `BadgeEngine` → 뱃지 그리드 UI 연결. 7종 뱃지 획득/잠금 실시간 반영. |
| `Features/Profile/ProfileScreen.swift` (내보내기) | `DataExporter` → 내정보 탭 "데이터 내보내기" 버튼 진입점 연결. `ShareLink` / `UIActivityViewController` 경유 JSON 공유. |
| `Features/QuickRecord/QuickRecordSheet.swift` | 빠른기록 시트에 **PhotosUI** `PhotosPicker` 통합 — 실기기 사진 라이브러리에서 사진 선택 후 기록 첨부. |
| `Features/ShareCard/ShareCardView.swift` | 성장카드에 **PhotosUI** `PhotosPicker` 통합 — 아이 실사진 선택 → 카드 합성(`ImageRenderer.renderCard`). |
| `BabyLogWidget/` (신규 타깃) | **WidgetKit** 위젯 Extension 타깃 추가(`com.babylog.app.widget`). `project.yml` Widget Extension 타깃 추가. |
| `BabyLogWidget/TodayTaskWidget.swift` | "오늘 할 일" 위젯 — PriorityEngine 상위 1건(임박 예방접종·기록 권유) Small/Medium. |
| `BabyLogWidget/BabySummaryWidget.swift` | "아이 요약" 위젯 — 아이 이름·월령·최근 기록 한 줄 요약. |
| `BabyLogWidget/NearbyEmergencyWidget.swift` | "주변 소아과" 위젯 — 저장된 즐겨찾기 1건 빠른 호출. |

### 주요 변경 사항

| 항목 | 내용 |
|---|---|
| **TickLab 프리미엄 색상** | 배경 화이트 + 딥 인디고 + 앤티크 골드 3색 체계로 전면 리스킨. 깔끔하고 고급스러운 인상. Liquid Glass 레이어와 대비 최적화. |
| **엔진 UI 3종 연결** | 라운드 6에서 ready 상태였던 PriorityEngine·BadgeEngine·DataExporter를 각 화면에 실제 바인딩. |
| **PhotosUI 실사진 picker** | `PHPickerViewController` 기반 `PhotosPicker` + 다운샘플링 — 빠른기록·성장카드 두 곳에서 실기기 사진 첨부 가능. |
| **WidgetKit 3종** | App Extension 타깃 신규 추가. 오늘 할 일·아이 요약·주변 소아과 3종 위젯. App Group 실데이터 공유는 후속(백로그). |

### 팀장 통합 완료

- Widget Extension `project.yml` 타깃 추가 + `Widget/Info.plist` `CFBundleIdentifier` 보강 (과학적 토론 해소)
- 위젯 3종 빌드 검증 + iPhone 위젯 갤러리 확인
- 전체 build+test **171/171 PASS** 확인 후 iPhone 재설치 완료

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
| 라운드 7 (TickLab 프리미엄 색상·엔진 UI·실사진·WidgetKit) | **171** | 테스트 추가 없음 (UI 연결·위젯·리스킨, 기존 171 유지) |
| 라운드 8 (홈 레이아웃 3안·빈상태/로딩/에러·네트워킹 인프라) | **171+** | +α (APIClient·SkeletonView·EmptyState·ErrorState·파서 테스트 추가) |

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
