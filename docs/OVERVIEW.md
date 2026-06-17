# BabyLog — 제품 전체 개요 (Product Overview)

> **아이의 모든 순간을 담다** — 임신을 확인한 순간부터 아이가 자라는 매일까지, 한 앱에.
>
> 최종 갱신: 2026-06-17 · 작성: 문서 담당 · 기준: 코드 as-built + `CLAUDE.md`/`SPEC.md`/`docs/CHANGELOG.md`
> 이 문서는 **현재 구현된 상태(as-built)** 기준의 단일 진입 문서입니다. 기획 풀스코프는 [`SPEC.md`](../SPEC.md), 절대 원칙·정책은 [`CLAUDE.md`](../CLAUDE.md), 변경 이력은 [`docs/CHANGELOG.md`](CHANGELOG.md)를 참조하세요.

---

## 1. 소개

**BabyLog(베이비로그)** 는 임신부터 육아까지 한 가족의 여정을 끊김 없이 담는 **iOS 육아 슈퍼앱**입니다. 1인 개발 프로젝트이며 SwiftUI로 만들어졌습니다.

### 한 줄 정의
임신 확인 → 태아 일지 → 출산 → 성장 기록 → 동네 인프라·거래·크루까지, **기록(아이의 평생)** 과 **연결(동네 이웃)** 을 하나로 묶은 앱.

### 누구를 위한 앱인가
- **부모(양육자)** — 임신·성장·접종·가계부를 한 곳에서 기록하고 평생 보존.
- **조부모·친척** — 앱이 없어도(안드로이드·PC) **웹 가족 피드**로 손주 사진을 보고 ❤️·댓글.
- **동네 이웃** — 중고 거래·동네 크루·주변 인프라(소아과·약국·키즈카페).

### 핵심 가치 — 데이터 연속성
임신 기록(Pregnancy)은 출산 시점에 아이(Child)로 **승계**됩니다. 배 사진 타임라인 → 성장 사진, 태명 → 아이 이름, 예정일 → 실제 생년월일. 태아 시절부터 성장까지 **하나의 끊김 없는 여정**을 만드는 것이 이 앱의 핵심 차별점입니다.

### 포지셔닝
"아이의 모든 순간을 담다" — 임신부터 육아까지 끊김 없는 기록을 중심에 둔 럭셔리·신뢰 포지셔닝. **무광고**, 다크패턴 없는 **정직한 결제**, 아동 데이터 비매각. (전략 축: 기록 + 동네 — 동네는 거래·크루 기능 영역.)

---

## 2. 절대 원칙 (타협 불가)

모든 구현에서 예외 없이 지키는 9대 원칙입니다.

| 원칙 | 내용 |
|---|---|
| **데이터 비매각** | 아동 데이터는 절대 외부에 판매하지 않음. 수익은 구독 + 거래 수수료로만. |
| **무료 데이터 영구 보존** | 무료 사용자의 데이터도 삭제하지 않음. "데이터 인질극" 금지. |
| **사진 서버 최소화** | **아동 기록 원본(성장·일기·접종·가계부·성장 보드)은 로컬/개인 iCloud(온디바이스), 우리 서버에 올리지 않음.** 우리 서버(R2)는 **가족 사진 공유**에 한해 사용(무료 부부 2명 / Pro 조부모·친척 최대 8명). '웹/크로스플랫폼 가족 공유 = Pro'가 수익 경계. |
| **무광고** | 광고 SDK 미도입. 직접 제휴만 허용. |
| **정직한 결제** | 다크패턴 금지. 자동결제 사전 고지, 해지는 쉽고 존중하는 톤. |
| **성별 중립** | UI 전반에서 '○○맘' 대신 '양육자/○○님'을 기본. 아빠·조부모·다양한 가족(입양·위탁·조손) 포용. |
| **아동 안전 최우선** | 사고 한 건이 브랜드를 죽인다. 안전 타협 불가. |
| **안정성 우선** | 새 기능보다 버그 없는 경험. |
| **데이터 주권** | 사용자가 언제든 표준 포맷으로 데이터를 내보낼 수 있어야 함. |

> ⚠️ **2026-06 정책 갱신**: 기존 "무료는 서버 비전송" 원칙을 **가족 사진 공유 범위에서만** 완화했습니다. 무료 2인 가족 피드도 R2를 사용합니다. 단, **아동 기록 원본은 여전히 서버에 올리지 않습니다**(로컬/개인 iCloud).

### 민감 영역 — 임신 상실 배려
임신 기록은 유산·사산 등 상실 가능성이 있는 가장 민감한 영역입니다.
- **"기록 멈춤" 모드** — 상실 시 모든 주차 알림·태아 가이드·권유 알림 즉시 중단.
- **미사용 신호 자동 감지** — 오래 미접속 시 권유 알림 자동 완화(사용자에게 설정 부담 X).
- **따뜻하고 중립적인 카피** — 절대 닦달하지 않음. 의료 조언은 직접 제공하지 않고 "병원 방문 권장 + 주변 소아과 연결"로 대응, 모든 건강 정보에 "의료 상담 대체 아님" 면책 명시.

---

## 3. 핵심 기능

상태 범례: ✅ 라이브 · 🟡 부분/키 대기 · 🔜 예정(v2~)

### 기능 1 — 임신 기록 & 태아 일지 ✅
임신 모드 홈/기록 탭. 주차(D+/주수) 표시, 산전검진 일정 자동 생성·알림, 배 사진 타임라인, 체중 차트. **출산 전환**("출산했어요" → Child 승계). 상실 시 기록 멈춤. 온보딩에서 예정일은 추정 금지(손 안 댄 채 '출산 임박' 거짓 주차가 생기지 않게 합리적 기본값).

### 기능 2 — 성장 기록 & 육아 일지 ✅
- **성장 기록** — 신장·체중·두위, Swift Charts(또래 비교는 안심 톤, 정밀 수치 옵트인).
- **육아 일지(다이어리)** — 사진·이정표·메모. 빠른 기록 2탭 완료.
- **성장 카드 공유** — ImageRenderer로 인스타용 카드 합성(얼굴 블러 옵션).
- **성장 보드(신규)** — 사진·메모·스티커를 자유 캔버스에 배치하는 보드 에디터. 무료 1개 / Pro 최대 100개, 대표(primary) 1개는 무료도 편집. 상세 §4·[`screens.md §10`](screens.md).
- **예방접종** — 출생~만 6세 스케줄, 그룹 상태 배지, 회차 카운트("N/M"), 병원 메모.

### 기능 3 — 주변 인프라 & 응급 모드 🟡
- **지도** — Apple MapKit 네이티브(키 불필요). 카카오 로컬 검색은 REST 키 입력 시 자동 Live 전환(현재 키 대기).
- **응급 모드** — 야간 약국·응급실 등 시간대 적응형.
- **위젯** — 주변 소아과 위젯 포함(WidgetKit 3종).

### 기능 4 — 육아 중고 마켓 & 렌탈 🟡
로컬 백본 완성 + Supabase 동기화 코드 준비(키 대기). 무료 1매물·30일 자동삭제 / Pro 다중판매·서버 풀화질 백업. 인증 우선, 신고 시 **대화 스냅샷 증거 보존**(분쟁·경찰 제출 대응).

### 기능 5 — 육아 가계부 & 정부지원금 ✅
- **지출** — 카테고리별 CRUD, 트리맵 분석 대시보드, 실통계.
- **정부지원금** — 아동수당·부모급여·첫만남이용권 등(복지로 연동). 카드 탭 시 **상세 팝업**(전체 설명·금액·신청 링크), 받음 표시.

### 기능 6 — 동네 육아 크루 & 커뮤니티 🟡
로컬 백본 + Supabase(동네 대기신청·게시판·채팅 코드 완료, 키 대기). **크루 그룹 생성 1인 1개**(참여는 무제한). 안전·신뢰 정책.

### 기능 7 — 뱃지 & 신뢰도 시스템 ✅
활동 기반 뱃지·신뢰도 티어, 프로필 카드 노출.

### 기능 8 — 정보구조 & 네비게이션 ✅
하단 5탭 + 우상단 빠른기록 FAB. §5 참조.

### 기능 9 — 온보딩 & 첫 사용자 경험 ✅
임신/육아 분기, 단계별 스킵 가능, 강제 입력 0, 권한 요청은 맥락에서.

### 기능 10 — 홈 화면 & 리텐션 루프 ✅
요약·진입점 홈. **우선순위 엔진**(시간대·상태 적응), "1년 전 오늘" 추억, 주간 리포트.

### 기능 11 — 알림 전략 ✅
추억 알림('N년 전 오늘')·검진 알림·접종 알림. **민감영역 차단**(상실·아이 삭제 시 관련 알림 즉시 취소, 백업·복원에도 끈 설정 존중).

### 기능 12 — AI 활용 🔜
온디바이스(Core ML) 가능 기능은 무료, 서버 LLM 필요 기능은 Pro. 'AI'를 전면에 내세우지 않고 경험에 내재화.

### 기능 13 — 접근성 & 사용 환경 ✅(지속)
VoiceOver 라벨·액션, 색약 대응(색+아이콘+레이블 3중 인코딩), 한 손 조작(하단 중심 버튼), Reduce Motion 존중. Dynamic Type 전면 적용·조부모 큰글씨는 별도 신중 패스로 진행 중.

### 기능 14 — 신뢰·안전 & 콜드스타트 🟡
신고 시스템·증거 보존 라이브. 사용자 차단 기능은 출시 전 항목.

### 기능 15 — 데이터·프라이버시 & 지표 ✅
표준 포맷 익스포트(데이터 주권), 개인 iCloud 백업, 계정 삭제. 법적 고지·개인정보처리방침 현행화.

---

## 4. 가족 사진 공유 (Pro 가족 피드) ✅ v1 라이브

조부모·친척과 사진을 나누는 **Supabase + Cloudflare R2 기반 가족 피드(앱 + 웹)**.

- **웹 클라이언트** — 안드로이드·PC 조부모도 `babylog-family.pages.dev/family/?invite=CODE`에서 **익명 로그인 + 성함 + 비밀번호**로 합류해 사진을 보고 ❤️·댓글(Apple ID 불필요).
- **등급** — 무료 **부부 2명**(플랫폼 무관) / Pro **8명**(조부모·친척). 합류는 **주인 승인제**(+합류 푸시).
- **구독 만료 게이팅** — 부부는 유지, 조부모·친척은 보기 차단(데이터 보존, 재구독 시 자동 복구).
- **영상 공유** — 무료 포함. 720p·60초 압축+포스터. 개수 상한 무료 100 / Pro 300(주인 등급 기준, 서버 강제).
- **무료 '배우자' 지정** — Pro로 여러 명 승인 후 만료 시, 지정된 배우자가 유지됨.
- 부부 '앱 전체 데이터(성장·일기·접종·가계부) 동기화'는 **CKShare 기반 v2 예정**(개인 iCloud, 우리 서버 X).
- 상세: [`PRO_FAMILY_FEED.md`](PRO_FAMILY_FEED.md).

---

## 5. 화면 구조 (UX)

### 하단 5탭
| 탭 | 역할 |
|---|---|
| **홈** | 요약·진입점(데이터 본체는 각 전용 탭) |
| **기록** | 아이 타임라인(성장·일기·접종·성장 보드) |
| **동네** | 주변/마일/크루 통합(위치 기반·시간대 적응형) |
| **가계부** | 지출·정부지원금 |
| **내정보** | 프로필·뱃지·구독·설정 |

### 핵심 UX 원칙
- **빠른 기록 = 우상단 프로필 FAB** — 한 손 엄지 동선. 탭하면 사진 선택 → 저장(2탭), 길게 누르면 빠른 메뉴. 설정에서 좌하단 이동 가능(왼손잡이).
- **2탭 완료** — FAB → 사진 선택 → 저장. 강제 입력 단계 0.
- **한 손 조작** — 중요 버튼은 엄지가 닿는 하단 중심.
- **또래 비교는 안심 톤** — 등수 경쟁 X, 기본은 정성적 안심 메시지.
- 화면별 상세: [`screens.md`](screens.md).

---

## 6. 등급 & 수익 모델

| 항목 | 무료 | Pro |
|---|---|---|
| 가족 피드 인원 | 부부 2명 | 8명(조부모·친척) |
| 가족 영상 개수 | 100 | 300 |
| 성장 보드 | 1개(대표만 편집) | 최대 100개·대표 변경 |
| 마켓 판매 | 1매물·30일 자동삭제 | 다중판매·서버 풀화질 백업 |
| 아동 기록 원본 | 로컬/개인 iCloud 백업 | 동일(서버 X) |

- **결제** — StoreKit 2 실결제(✅ 라이브). 월 **₩990** / 연 **₩9,900**. 서버 영수증 검증(운영→샌드박스 폴백).
- **수익원** — 구독 + (향후) 거래 수수료. 광고 없음, 아동 데이터 비매각.

---

## 7. 기술 스택 & 아키텍처

| 영역 | 스택 (현재 as-built) |
|---|---|
| 클라이언트 | SwiftUI (iOS 17+, Xcode 26.5, XcodeGen 관리) |
| 로컬 영속 | **JSON 디스크**(`CodablePersistence`/`PersistableState`, App Group) |
| 개인 백업 | **CloudKit** 개인 iCloud private DB (`BL_CLOUDKIT`) — 우리 서버 X |
| 백엔드(가족 피드·마켓·크루) | Supabase(Postgres·Auth·Storage·Realtime) + Cloudflare R2 |
| 결제 | StoreKit 2 |
| AI | Core ML(온디바이스) + 서버 LLM(Pro) — 일부 예정 |
| 차트 | Swift Charts |
| 위젯 | WidgetKit (3종) |
| 카드 합성 | ImageRenderer + Core Graphics |

> 참고: CLAUDE.md/SPEC.md는 장기 목표로 **CoreData + CloudKit**을 명시합니다. 현재는 JSON 디스크 + CloudKit 백업이며, CoreData 마이그레이션은 후속 단계입니다([`data-and-persistence.md §7`](data-and-persistence.md)).

### 아키텍처 규칙 (5년을 좌우하는 기반)
- **SPM 모듈화**(목표) — 기능별 독립 패키지로 1인 유지보수 분산.
- **공통 이벤트 버스** — 기능 간 연결(이정표 달성 → 추천 트리거)을 처음부터 표준화(`EventBus`/`AppEvent`).
- **다국어 문자열 분리** — 텍스트 하드코딩 지양(국제화 옵션 확보).
- **데이터 표준 익스포트** — 데이터 주권·서비스 종료 대비.
- **원격 구성(피처 플래그)** — 동네별 점진 개방·심사 없는 핫픽스.
- **온디바이스 우선** — 프라이버시 보전 + 서버 비용 절감.
- 상세: [`architecture.md`](architecture.md).

---

## 8. 데이터 모델 & 백업

### 핵심 엔티티
`Pregnancy`(임신) → 출산 시 → `Child`(아이) → `GrowthRecord`(성장)·`DiaryEntry`(일지)·`VaccineRecord`(접종)·`GrowthBoard`(성장 보드). 그 외 `Expense`(가계부)·마켓·크루.

### 영속화 3계층
1. **로컬 디스크** — `PersistableState` 전체를 JSON으로 App Group에 원자적 저장(`objectWillChange` autoPersist).
2. **개인 iCloud 백업** — `CloudSyncService`가 전체 상태를 개인 iCloud private DB에 백업·복원. 저장 정책 `.allKeys`(last-writer-wins, oplock 회피). `.background` 전환 + `BGProcessingTask`로 자동 백업, 미로그인 시 안내. 마지막 백업 시각 표시.
3. **사진** — 보드 전용 사진 등은 iCloud로 증분 업로드. 아동 기록 원본은 로컬/개인 iCloud만.

> 앱 로그인(가족 피드·크루, Supabase)과 기기 iCloud 백업(Apple ID·CloudKit)은 **별개**입니다.
> 상세: [`data-and-persistence.md`](data-and-persistence.md).

---

## 9. 외부 API (전부 무료)
- **질병관리청 예방접종도우미** — 예방접종 스케줄
- **건강보험심사평가원** — 소아과/약국 정보
- **카카오맵 로컬 API** — 주변 장소(키즈카페 등)
- **복지로 API** — 정부지원금
- **KATSA/KERI 리콜 DB** — 카시트 등 리콜 조회

키 발급·연동 절차: [`integration-backend.md`](integration-backend.md), [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md).

---

## 10. 운영 · 보안 · 법적
- **관리자 모드** — 로그인 + 버전 10탭 진입, 권한은 서버(admin Edge)가 JWT uid 화이트리스트(`ADMIN_UIDS`)로 강제. PIN·개발용 Pro 강제는 일반 사용자 도달 불가. 접속 통계·신고 스냅샷.
- **보안 원칙** — `Secrets.plist`는 gitignore(절대 커밋 금지). 공유 인프라 RLS 비활성 금지. R2 시크릿은 출시 전 로테이션.
- **인증** — [`AUTH_SETUP.md`](AUTH_SETUP.md) · **푸시** — [`PUSH_SETUP.md`](PUSH_SETUP.md) · **계정 삭제** — [`ACCOUNT_DELETE_DEPLOY.md`](ACCOUNT_DELETE_DEPLOY.md) · **법적** — [`OPERATOR_LEGAL.md`](OPERATOR_LEGAL.md).

---

## 11. 프로젝트 구조 & 빌드

### 디렉터리
```
App/Sources/        SwiftUI 앱 소스
  Data/             AppStore·모델·영속화·CloudSync
  Features/         기능별 화면(GrowthBoard·Budget·Record·Family·Settings…)
  Shell/            MainTabView·탭·FAB
  DesignSystem/     토큰·모션·컴포넌트
  Networking/       APIClient·Provider
App/Resources/      Assets(스티커 등)
Tests/BabyLogTests/ 단위 테스트
web/family/         조부모용 웹 가족 피드(Cloudflare Pages)
docs/               문서
```

### 빌드 (요약)
```bash
brew install xcodegen
xcodegen generate          # .swift 파일 추가 시 필수(테스트 타깃 포함)
# Xcode에서 BabyLog 스킴 빌드/실행, 또는:
xcodebuild -project BabyLog.xcodeproj -scheme BabyLog -destination 'generic/platform=iOS' build
```
상세: [`setup-and-build.md`](setup-and-build.md) · 테스트 전략: [`testing.md`](testing.md).

---

## 12. 현황 & 로드맵

### 현재 상태 (2026-06-17)
- 5탭 전부 실화면 + 성장 보드 라이브. 테스트 **362개**(보드 13개 포함).
- StoreKit 2 구독·개인 iCloud 백업·가족 피드 v1 라이브.
- 실기기(iPhone) 설치·실행 확인.

### 출시 전 남은 항목
- 카카오/Supabase 등 외부 키 입력(마켓·크루·키즈카페 Live 전환)
- R2 시크릿 로테이션, ASC 구독 상품 등록, UGC 게이트 EULA, 사용자 차단 기능
- 테스트 타깃 정리: `AppStorePregnancyLogTests`가 제거된 태동 API를 참조(삭제 또는 기능 복구 결정 필요)

### v2 이후
- 부부 앱 전체 데이터 CKShare 동기화 · CoreData 마이그레이션 · SPM 모듈화 · 안드로이드(KMP/Flutter) 확장 · 서버 LLM AI

장기 비전: [`roadmap-status.md`](roadmap-status.md), `SPEC.md` 부록 C.

---

## 13. 문서 맵

| 문서 | 내용 |
|---|---|
| [`SPEC.md`](../SPEC.md) | 기능 풀스코프(15개 + 부록), 30라운드 토론 반영 |
| [`CLAUDE.md`](../CLAUDE.md) | 절대 원칙·민감영역·아키텍처 규칙·작업 방식 |
| [`README.md`](../README.md) | 저장소 진입(가치·스택·빌드) |
| **OVERVIEW.md** (이 문서) | as-built 제품 전체 개요 |
| [`docs/CHANGELOG.md`](CHANGELOG.md) | 변경 이력 |
| [`docs/architecture.md`](architecture.md) | 아키텍처 상세 |
| [`docs/data-and-persistence.md`](data-and-persistence.md) | 데이터 모델·영속화·백업 |
| [`docs/screens.md`](screens.md) | 화면별 명세 |
| [`docs/design-system.md`](design-system.md) | 디자인 토큰·컴포넌트 |
| [`docs/PRO_FAMILY_FEED.md`](PRO_FAMILY_FEED.md) | 가족 피드(앱·웹·서버) |
| [`docs/integration-backend.md`](integration-backend.md) · [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md) · [`AUTH_SETUP.md`](AUTH_SETUP.md) · [`PUSH_SETUP.md`](PUSH_SETUP.md) | 백엔드·키 연동 |
| [`docs/OPERATOR_LEGAL.md`](OPERATOR_LEGAL.md) · [`ACCOUNT_DELETE_DEPLOY.md`](ACCOUNT_DELETE_DEPLOY.md) | 운영·법적·계정 삭제 |
| [`docs/testing.md`](testing.md) · [`setup-and-build.md`](setup-and-build.md) | 테스트·빌드 |
| [`docs/KNOWN_ISSUES.md`](KNOWN_ISSUES.md) · [`BACKEND_TODO.md`](BACKEND_TODO.md) | 알려진 이슈·백엔드 TODO |
