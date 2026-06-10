# BabyLog 구현 프로세스 로그 (process.md)

> 팀장(lead)이 구현 단계가 진행될 때마다 갱신하고 git 커밋한다.

---

## 2026-06-10 — Phase 0: 팀 세팅 & 스펙 확인

**상태:** ✅ 완료 (디자인 파일 수령 대기)

### 수행 내용
- 작업 환경 확인: 작업 폴더 비어 있음, git 미초기화, tmux 3.6a / claude CLI / git 2.52.0 사용 가능 확인
- git 저장소 초기화 (branch: `main`)
- 팀 조정 인프라 구축:
  - `team/TEAM.md` — 팀 헌장 (구성·작업 사이클·협업 프로토콜·절대 원칙·기술 스택)
  - `Tasklist.md` — 전체 진행 추적 보드 + 토론/교차영향/가설 로그
  - `process.md` — 본 프로세스 로그
- 스펙 정독 (팀장): `CLAUDE.md`(제품 철학·절대 원칙·민감 영역·아키텍처 규칙) + `SPEC.md`(기능 1~14 + 부록 A/B/C + 수익 로드맵)

### 핵심 확인 사항 (팀장 요약)
- 제품 한 줄: "우리 둘다 육아의 모든 것" — 임신부터 졸업까지 끊김 없는 하나의 서사
- v1 MVP 범위: **성장 기록(기능2) + 주변 인프라(기능3)**, 8주 타임박스
- 핵심 연결 가치: 임신기록(기능1) → 출산 전환 → 성장기록(기능2)의 데이터 연속성
- 데이터 모델 연속성이 설계 최우선 (Pregnancy → Child 승계)

### 팀원 스펙 확인 완료 (병렬, Sonnet)
- 원본 `CLAUDE.md`/`SPEC.md`를 `/Users/kjmoon/Downloads/`에서 작업 폴더로 복사(정상 인코딩 확인)
- tmux 대시보드 세션 `babylog` 가동 (`team/dashboard.sh`)
- Teammate 1~4가 각자 `team/confirmations/{coder,debugger,qa,perf-doc}.md` 작성 후 보고:
  - **Coder**: 8개 엔티티 정리, Pregnancy→Child는 `Child.pregnancyId` 외래키 승계, 상실 시 `status=.loss` 즉시 예약알림 취소. SPM: BLCore→BLData→BLGrowth/BLInfra/BLPregnancy 제안.
  - **Debugger**: 최고위험 ①Pregnancy→Child 전환 원자성(partial migration) ②'기록 멈춤' 트리거 미정(동기화 지연 중 가족 기기 알림 도달이 가장 치명적) ③CloudKit 동시편집 무음소실.
  - **QA**: 최우선 테스트 ①데이터 승계 ②주수/월령 계산 ③WHO 백분위+예방접종 스케줄. 원칙 충돌 2건 발견(광고/뱃지명).
  - **Perf/Doc**: 핫스팟 ①사진 타임라인 스크롤(썸네일 캐시) ②카드 합성(2단계) ③외부 API 과호출(디바운싱·캐시). 문서 `docs/` 5분할 제안.

### 팀장(아키텍트) 통합 판단
- 수렴 발견을 `Tasklist.md` 토론/교차영향 로그 + 오픈 질문 보드(A/B/C/D)로 통합
- **A(원칙)**: 오너 결정 대기 — v1 비차단. **B(아키텍처)**: Phase 2 팀장 확정 예정 — v1 코드 선결. **C(디자인)**: 파일 수령 후. **D(계산 컨벤션)**: 기본값 제안 + 오너 확인.
- 핵심 선결: B1(SPM/CoreData 경계) → B2(status enum) 순으로 Phase 2 착수 시 즉시 확정 필요

### 대기 중
- **디자인 파일 수령** (사용자가 이어서 전달 예정) → Phase 1 UX 설계 착수 트리거

### 다음 단계
- 디자인 파일 수령 시 Phase 1(UX 설계) 진입 → Phase 2(아키텍처 B1~B4 확정) → Phase 3 v1 MVP 구현

---

## 2026-06-10 — 스펙 v0.2 업데이트 반영 & 오너 결정

**상태:** ✅ 완료 (디자인 파일 수령 대기 유지)

### 스펙 업데이트 반영 (CLAUDE.md · SPEC.md)
- **네비게이션 확정**: 3축 IB → **5탭 하단 네비(홈·기록·동네·가계부·내정보) + 우상단 빠른 기록 프로필 버튼(FAB)**
- SPEC에 **기능 8 '정보구조 & 네비게이션' 신설** (8.1 5탭 구조 / 8.2 핵심 설계 원칙 / 8.3 동네 탭 세그먼트 / 8.4 FAB / 8.5 화면 간 이동)
- 기존 기능 8~14 → **9~15로 재번호**, 본문 교차참조 2곳(기능 11 알림, 주간 리포트 기능 10) 정정
- CLAUDE.md UX 원칙에 5탭·FAB·동네 세그먼트 항목 추가
- 적용 방식: 작업 폴더의 정상 인코딩본에 델타만 정밀 치환(17개) 후 검증 — Downloads 원본은 구버전이라 미사용

### 오너 결정 반영
- **A1 (무광고 vs v3 배너광고): 보류** — 추후 적용, v1 비차단
- **A2 (성별 중립 vs 골든 맘): 해소** — '골든 파파' 추가, 최상위 티어를 '골든 맘/골든 파파' 호칭 선택형(중립 옵션 가능)으로. SPEC 7.2 반영 완료
- **D (계산 컨벤션): 유지·확정** — D3 '기록 멈춤' 자동 억제 임계값을 **미접속 30일**로 확정

### 대기
- 디자인 파일 수령 대기 (수령 시 Phase 1 착수, 5탭 셸 + FAB부터 설계)

---

## 2026-06-10 — Flutter→Swift 전환 · 디자인 검토 · 파운데이션 구현

**상태:** ✅ 파운데이션 BUILD SUCCEEDED (iOS26 SDK, arm64+x86_64 시뮬)

### 프레임워크
- Flutter 스캐폴드 생성 후 오너 지시로 **Swift/SwiftUI 확정** → Flutter 산출물 전량 제거
- 근거: 리퀴드 글래스(iOS26) = SwiftUI 네이티브 `.glassEffect`/`TabView`가 가장 충실. Xcode 26.5 환경.

### 디자인 검토 (화면 구성)
- Downloads/BabyLog 디자인 핸드오프(React/JSX + DS CSS + 스크린샷) + DESIGN.md(v1.0) 정독
- 검토 결과 → [DESIGN_REVIEW.md](team/DESIGN_REVIEW.md) (IA 5탭 확정, 화면별 검토, 리스크 R1~R4, 토큰→Swift 매핑)
- 디자인 레퍼런스를 `design/handoff/`로 반입(대용량 standalone html 제외)

### 구현 (Phase 3 파운데이션, 빌드 검증)
- XcodeGen `project.yml` — App 단일 타깃, iOS 17+ 배포, iOS26 기능 @available 게이트
- 디자인 시스템: AppColors(라이트·다크)·AppTypography·AppMetrics·**LiquidGlass(네이티브)**·**LiquidButton(.bl-liquid)**
- 컴포넌트: BLCard/BLBadge/BLChip/BLSectionHead/PhotoPlaceholder
- 셸: MainTabView(5탭, 시스템 Liquid Glass 탭바) + QuickRecordFAB(스피드다이얼) + 홈(스크린샷 재현)·동네(세그먼트)·기록·가계부·내정보

### 다음
- 병렬 워크플로우로 Phase 3 본구현 (데이터 레이어 · 테스트 · 문서 · 리스크 감사)

---

## 2026-06-10 — Phase 3 병렬 통합 (Coder·QA·Debugger·Doc)

**상태:** ✅ 통합 빌드 + 테스트 성공 (**27/27 PASS**)

### 병렬 산출물 통합
- **coder**: Core+Data (AgeCalculator·Models·PregnancyTransition·EventBus) — 앱 빌드 ✅
- **qa**: 27개 단위테스트(`Tests/BabyLogTests`) — test 타깃 `project.yml` 추가, 시뮬 실행
- **debugger**: `team/debug/phase3-risk-audit.md` (리스크 A~E + 가설 H1~H5)
- **doc**: `README.md` + `docs/{architecture,design-system,setup-and-build}.md`

### 과학적 토론 — 교차레이어 버그 발견·해소
- QA 테스트가 Coder 이름 검증 결함 적발: `childName="\n"`이 통과(`.whitespaces`만 트림)
- 결론: `.whitespacesAndNewlines`로 수정 → **27/27 통과**
- 디버거 D-FIX 즉시 반영: LiquidButton `onDisappear` 애니 중단, FAB 하위액션 VoiceOver 라벨

### 디버거 후속 과제 (Phase 3 본구현에서)
- 상실 이벤트(`pregnancyEndedInLoss`) 구독 → 알림 취소 (민감영역 최우선)
- Pregnancy→Child CoreData 트랜잭션 원자성/복구 (B2)
- AgeCalculator UTC 정규화 + LMP>오늘/미래 birthDate 입력 검증
- ink3-on-canvas WCAG AA 대비 재검토

---

## 2026-06-10 — Phase 3 라운드 2 통합 (상실 알림 차단·원자 전환·기록 화면)

**상태:** ✅ 통합 build + test 성공 (**43/43 PASS**)

- **coder-data**: `NotificationService`(상실→알림 자동 취소, `preg-<id>` prefix) + `AppStore`(원자적 전환)
- **coder-ui**: `RecordScreen`(타임라인·성장차트 Swift Charts WHO밴드+안심메시지·예방접종) + `MainTabView` 연결
- **qa**: 알림차단·원자성 테스트 16개 (상실/실패 시 store 무변경 검증)
- **perf-doc**: `docs/data-and-persistence.md`, `docs/testing.md`

### 과학적 토론(해소)
- 통합 빌드 시 `AppStore.commitBirthTransition`의 guard else fall-through 컴파일 에러 → switch 문으로 정리(팀장 수정)

### 디버거 후속과제 충족
- 상실 알림 자동 차단(민감영역 1위험) ✅ 구현+테스트
- Pregnancy→Child 전환 원자성(B2) ✅ 도메인 레벨(무변경 보장)+테스트 — CoreData+CloudKit 영속화는 후속 인프라

### 남은 과제
- AgeCalculator UTC 정규화 / 입력검증 · ink3 WCAG 대비 · EventBus 테스트 격리(주입) · CoreData 영속화 · 화면(온보딩·동네·홈 임신모드)

---

## 2026-06-10 — Phase 3 라운드 3 통합 ("전부 진행": 화면 4종 + 인프라)

**상태:** ✅ 통합 build+test 성공 (**61/61 PASS**) · GitHub 푸시

6명 병렬 산출물:
- 온보딩(임신/출산 분기·강제입력0) + 임신모드 홈(`PregnancyHomeView`)
- 빠른기록 시트(`QuickRecordSheet`, 2탭+보상)
- 성장카드 공유(`ShareCardView` + `ImageRenderer.renderCard`)
- 인프라: AgeCalculator 입력검증, EventBus 격리(`init` 개방), AppStore 버스 주입+snapshot/restore, `LocalPersistence`(Codable)
- qa: 검증·버스격리·영속화 테스트 16
- doc: `docs/screens.md`, `docs/roadmap-status.md`

팀장 통합:
- **Shell 와이어링**: 온보딩 게이트(`@AppStorage`), FAB→`QuickRecordSheet`(.sheet detents), 좌하단 모드 전환(Liquid Glass 칩)→임신홈
- **과학적 토론(해소)**: ShareCard 문자열 따옴표 미이스케이프 컴파일에러 → 수정
- 검증: `xcodebuild test` **61/61 PASS**

### 남은 와이어링
- 성장카드 공유 진입점(기록 화면 공유 버튼) — 화면 자체는 컴파일·available, 진입 1줄

---

## 2026-06-10 — Phase 3 라운드 4 통합 + 실기기 설치 + 라이트모드

**상태:** ✅ build+test **87/87 PASS** · iPhone 설치·실행 성공 · GitHub 푸시

- **동네**(NearbyScreen + EmergencyScreen 다크 풀스크린), **외부 API 스텁**(질병청·카카오맵·심평원·복지로 Mock), **영속화 자동연결**(AppStore autosave/restore) + SampleData, qa 테스트
- **Shell 와이어링**: 동네 주변→NearbyScreen · 응급 fullScreenCover · 성장카드 공유 진입점(기록 헤더 `.sheet`)
- **라이트 모드 고정**(Info.plist `UIUserInterfaceStyle=Light`)
- **과학적 토론(해소)**: networking `public`↔internal 충돌 · `mockPlaces` 파일프라이빗 접근 → 수정
- **실기기**: 팀 `R3K972V8DA`(계정 세션 없음)→`QN975MTM7H`로 정정 후 `devicectl` 설치·실행 성공
- 검증: `xcodebuild test` **87/87 PASS**

---

## 2026-06-10 — Phase 3 라운드 5 통합 (남은 화면 본구현)

**상태:** ✅ build+test **111/111 PASS** · iPhone 재설치 · GitHub 푸시

- **가계부**(BudgetScreen: 도넛·정부지원금 전면·BudgetSummary), **내정보**(ProfileScreen: 티어 진행·뱃지 컬렉션·Pro·TierCalculator), **임신 기록 탭**(PregnancyRecordScreen: 태동 카운터·체중 차트·배사진 D라인·산전검사 + BirthTransitionView), **동네 마켓**(MarketScreen)·**크루**(CrewScreen 콜드스타트)
- qa: BudgetSummary·TierCalculator 19 테스트
- Shell 와이어링: 5탭 전부 실화면 + 임신모드 record→PregnancyRecordScreen
- 이번 라운드 **컴파일 버그 0** (계약 정합 우수)

### 현재 앱 상태 (judgeable)
온보딩 → 홈(육아/임신 모드) → 기록(타임라인·성장차트·예방접종 / 임신: 태아가이드·태동·배사진) → 동네(주변·응급·마켓·크루) → 가계부(지원금·도넛) → 내정보(티어·뱃지·Pro). + 빠른기록 시트, 성장카드 공유, 상실 알림 차단, 로컬 영속화, 외부 API 스텁. 라이트 모드. **테스트 111개.**

---

## 2026-06-10 — Phase 3 라운드 6 통합 (알림 스케줄링·엔진 3종·데이터 주권)

**상태:** ✅ build+test **171/171 PASS** · iPhone 재설치 · GitHub 푸시

- **알림 스케줄러**(NotificationScheduler vaccineReminders + UNPendingScheduler 권한/등록) → **앱 런치 연결**(권한 다이얼로그 + D-7/D-1/당일 등록)
- **홈 우선순위 엔진**(PriorityEngine), **뱃지 자동부여**(BadgeEngine), **데이터 내보내기**(DataExporter JSON 주권) — 테스트 완료·available
- qa: 엔진 4종 60 테스트 / doc: `docs/CHANGELOG.md`
- **과학적 토론(해소)**: PriorityItem.referenceId 추가 · DataExport 테스트 수정 · vaccineReminders fireDate 전역 정렬(QA 예측 적중)
- 검증: **171/171 PASS**

### 남은 UI 연결 (엔진은 ready)
- PriorityEngine→홈 카드 · BadgeEngine→뱃지 그리드 · DataExporter→내정보 내보내기 버튼

---

## 2026-06-10 — Phase 3 라운드 7 통합 (프리미엄 리스킨 + 엔진 UI + 위젯)

**상태:** ✅ build+test **171/171 PASS** · iPhone 설치(위젯 포함) · GitHub 푸시

- **TickLab 참고 프리미엄 색상**: 배경 화이트(#FFFFFF) + 딥 인디고(#1A1B2E) + 앤티크 골드(#C9A961) — 깔끔·고급. 토큰 이름 유지로 전 화면 자동 반영.
- **엔진 UI 연결**: PriorityEngine→홈 우선순위 카드 · BadgeEngine→뱃지 그리드 획득/잠금 · DataExporter→내정보 "데이터 내보내기" → 공유 시트
- **실사진 picker**(PhotosUI PhotosPicker + 다운샘플): 빠른기록 시트·성장카드 배경 실제 사진
- **WidgetKit 위젯**(신규 extension 타깃 com.babylog.app.widget): Small/Medium — 아이 요약·오늘 할 일·주변 소아과
- doc: CHANGELOG 갱신
- **과학적 토론(해소)**: 위젯 임베드 번들ID 빈값 → Widget/Info.plist CFBundleIdentifier 보강 후 통과
- 검증: 171/171 PASS, 디바이스 빌드(앱+위젯 서명) 성공·설치

### 비고
- 실행은 기기 잠금 해제 필요(FBSOpenApplicationError Locked) — 코드 무관
- App Group(group.com.babylog.app) 위젯 실데이터 공유는 후속

---

## 2026-06-10 — Phase 3 라운드 8 통합 (홈 레이아웃 3안·UX 상태·네트워킹 인프라)

**상태:** ✅ build+test **180/180 PASS** · iPhone 재설치 · GitHub 푸시

- **홈 레이아웃 3안**(히어로/대시보드/타임라인, `@AppStorage` 전환, PriorityEngine 연결 유지)
- **빈상태·로딩(Skeleton)·에러 UX 컴포넌트**(`Components/StateViews`: BLEmptyState·BLExpectationState·BLSkeleton·BLErrorState)
- **네트워킹 인프라**(APIClient·APIConfig·Live/Mock 폴백·공공API 파서 HIRA/Kakao/Bokjiro/KDCA)
- qa: APIError·mapHTTP·파서 throws 테스트 / doc: CHANGELOG
- **과학적 토론(해소)**: 파서 계약 불일치(루트배열 vs 공공API 래퍼+컨텍스트 인자) → 현실적 파서 채택, QA 테스트 포맷-무관 재작성
- 검증: **180/180 PASS** · 실행은 기기 잠금 해제 필요(코드 무관)

### 남은 백로그 (별도 전용 라운드 권장)
- CoreData+CloudKit 실영속화 · App Group 위젯 실데이터 · 외부 API 실키 연동 · 온보딩→실데이터 흐름 · SPM 모듈화 · 다크모드 재정비 · Pretendard 폰트

---

## 2026-06-10 — Phase 3 라운드 9 통합 (앱 실데이터 백본 · 옵션 A)

**상태:** ✅ build+test **198/198 PASS** · GitHub 푸시 · iPhone 재설치 보류(기기 연결 끊김)

- **AppStore API**(lead): `selectedChild`·`activePregnancy`·`hasContent`·`completeBabyOnboarding(name:birthDate:gender:)`·`startPregnancy(lmp:edd:nickname:)` + `selectedChildId`
- **앱 주입**(lead): `BabyLogApp`에 `@StateObject AppStore(persistence:)` + `.environmentObject` + `enableAutoPersist()`. MainTabView 게이트 = `onboarded || store.hasContent`
- **온보딩→실데이터**(lead): OnboardingView가 완료 시 입력값을 `completeBabyOnboarding`/`startPregnancy`로 AppStore에 기록
- **홈·임신홈 실데이터**(coder): `store.children`(다자녀 칩)·`selectedChild`·`activePregnancy`로 이름·D+일·월령·주수 표시, 폴백 포함
- qa: AppStore 온보딩/선택/영속화 18 테스트
- **흐름 완성**: 온보딩 입력 → AppStore(Codable 디스크 영속화) → 홈이 실제 아이 표시, 앱 재실행해도 유지
- 검증: **198/198 PASS**, 컴파일 버그 0

### 비고 / 남은 실데이터
- iPhone 연결 끊김으로 재설치 보류(재연결 시 `devicectl` 설치) — 코드 무관
- RecordScreen·ProfileScreen의 store 연결, 기록(GrowthRecord/DiaryEntry) CRUD는 후속

---

## 2026-06-10 — 앱 아이콘 + 라운드 10 (런치스크린 + 실데이터 CRUD)

**상태:** ✅ build+test **214/214 PASS** · iPhone 재설치 · GitHub 푸시

- **앱 아이콘**(커밋 9107edb): 세이지+골드 on 크림, 1024 Asset Catalog(알파 제거)
- **런치스크린**: 로고 + 크림(#FAFAF7) 배경 (흰 플래시 제거, 브랜드 스플래시)
- **실데이터 CRUD**:
  - AppStore: `growthRecords`/`diaryEntries` + `addDiaryEntry`/`addGrowthRecord`/`diaryEntries(for:)`/`growthRecords(for:)`, PersistableState 하위호환 디코딩
  - 빠른기록 시트 → 선택 아이에 실제 저장(보상 애니 유지)
  - RecordScreen 타임라인·성장차트가 store 실기록 표시 + BLEmptyState(권유 톤), 내정보 내보내기 store 연결
  - qa: 기록 CRUD·하위호환·영속화 16 테스트
- **완성 흐름**: 빠른기록 저장 → RecordScreen 실시간 반영 → 앱 재실행해도 유지
- 검증: **214/214 PASS**, 컴파일 버그 0

### 다음
- **B**: 외부 API 실키 연동 (ProviderFactory→화면, 키 필요)
- **C**: CloudKit 가족공유 / App Group 위젯 실데이터 (엔타이틀먼트)
