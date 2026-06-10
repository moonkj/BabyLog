# BabyLog

> **우리 동네 육아의 모든 것** — 임신 확인 순간부터 아이가 자라는 매일까지, 기록·동네·거래·가계부를 하나의 앱에 담은 iOS 육아 슈퍼앱.

---

## 핵심 가치 & 절대 원칙

BabyLog는 다음 원칙을 어떤 상황에서도 타협하지 않습니다.

| 원칙 | 내용 |
|---|---|
| 데이터 비매각 | 아동 데이터는 절대 외부에 판매하지 않음. 수익은 구독 + 거래 수수료로만. |
| 무료 데이터 영구 보존 | 무료 사용자의 데이터도 삭제하지 않음. "데이터 인질극" 금지. |
| 사진 서버 비저장 | 무료는 로컬/iCloud 저장, 서버 백업은 Pro 혜택. 이것을 마케팅 포인트로 활용. |
| 무광고 | 광고 SDK 미도입. 럭셔리 포지셔닝과 상충. 직접 제휴만 허용. |
| 정직한 결제 | 다크패턴 금지. 자동결제 사전 고지, 해지는 쉽고 존중하는 톤. |
| 성별 중립 | UI 전반에서 '○○맘' 대신 '양육자/○○님' 기본. 다양한 가족 포용. |
| 아동 안전 최우선 | 사고 한 건이 브랜드를 죽인다. 안전 타협 불가. |
| 안정성 우선 | 새 기능보다 버그 없는 경험. |
| 데이터 주권 | 사용자가 언제든 표준 포맷으로 데이터를 내보낼 수 있어야 함. |

---

## 기술 스택

| 영역 | 스택 |
|---|---|
| 클라이언트 | SwiftUI (iOS 17+, Xcode 26.5) |
| 로컬/동기화 | CoreData + CloudKit |
| 백엔드 (v2~) | Supabase (Postgres · Auth · Storage · Realtime) |
| 결제 | StoreKit 2 |
| AI | Core ML (온디바이스, 무료) + 서버 LLM (Pro) |
| 차트 | Swift Charts |
| 위젯/워치 | WidgetKit + Apple Watch |
| 카드 합성 | ImageRenderer + Core Graphics |
| 시그니처 UI | iOS 26 Liquid Glass (`.glassEffect`) |

---

## 빌드 & 실행 방법

### 요구사항

- **Xcode 26.5** 이상
- **Swift 5.0** 이상
- **XcodeGen** 필수 (`project.yml`로 `.xcodeproj`를 생성)

### 클론 후 첫 빌드

```bash
# 1. XcodeGen 설치 (Homebrew)
brew install xcodegen

# 2. 저장소 클론
git clone <repo-url>
cd BabyLog

# 3. .xcodeproj 생성
xcodegen generate

# 4-A. Xcode에서 열기
open BabyLog.xcodeproj

# 4-B. CLI 빌드 (서명 없이 시뮬레이터)
xcodebuild \
  -scheme BabyLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

> `project.yml`이 프로젝트 단일 출처입니다. `.xcodeproj`는 git에서 관리하지 않으므로, 클론 후 반드시 `xcodegen generate`를 먼저 실행하세요.

---

## 폴더 구조

```
BabyLog/
├─ project.yml                  # XcodeGen 프로젝트 정의 (단일 출처)
├─ CLAUDE.md                    # AI 팀원 공통 작업 지침
├─ SPEC.md                      # 전체 기능 스펙 (v0.2)
├─ DESIGN.md                    # 디자인 시스템 상세
├─ App/
│  └─ Sources/
│     ├─ BabyLogApp.swift       # 앱 진입점
│     ├─ DesignSystem/          # 디자인 토큰 & 시그니처 이펙트
│     │  ├─ AppColors.swift     # 색상 토큰 (라이트/다크 적응형)
│     │  ├─ AppTypography.swift # 타이포 스케일 9단계
│     │  ├─ AppMetrics.swift    # 간격·라운드·그림자
│     │  └─ LiquidGlass.swift  # iOS 26 Liquid Glass 확장
│     ├─ Components/            # 재사용 UI 컴포넌트
│     │  ├─ BLComponents.swift  # BLCard·BLBadge·BLChip·BLSectionHead·PhotoPlaceholder
│     │  └─ LiquidButton.swift  # 시그니처 리퀴드 CTA 버튼
│     ├─ Shell/                 # 네비게이션 셸
│     │  ├─ MainTabView.swift   # 5탭 하단 네비 + FAB 오케스트레이션
│     │  ├─ QuickRecordFAB.swift# 스피드다이얼 빠른 기록 버튼
│     │  └─ Tabs.swift          # 탭별 화면 골격
│     ├─ Core/                  # 비즈니스 로직
│     │  ├─ EventBus.swift      # 공통 이벤트 버스 (Combine)
│     │  └─ AgeCalculator.swift # 월령 계산
│     └─ Data/                  # 데이터 모델
│        ├─ Models.swift         # Pregnancy·Child·GrowthRecord 등
│        └─ PregnancyTransition.swift # 임신→출산 승계 로직
├─ design/
│  └─ handoff/                  # 디자인 핸드오프 자산
│     ├─ README.md              # 핸드오프 명세 (토큰·IA·화면별)
│     └─ design_files/
│        ├─ babylog-ds.css      # 디자인 토큰 원본
│        ├─ 00 Design System.html
│        └─ app/*.jsx           # 화면별 픽셀·카피 참조 (React)
├─ team/
│  ├─ TEAM.md                   # 팀 헌장 & 협업 프로토콜
│  └─ DESIGN_REVIEW.md          # 디자인 검토 기록
└─ docs/
   ├─ architecture.md           # 아키텍처 상세
   ├─ design-system.md          # 디자인 시스템 사용 가이드
   └─ setup-and-build.md        # 환경 설정 & 빌드 가이드
```

---

## 개발 로드맵

| 버전 | 포함 기능 | 목표 MAU |
|---|---|---|
| **v1 MVP** | 성장 기록 + 주변 인프라 (소아과·약국·응급 모드) | 5,000 |
| **v2** | 중고 마켓 + 가계부 + Pro 구독 | 15,000~30,000 |
| **v2.5** | 렌탈 + 카드 연동 | 50,000 |
| **v3** | 동네 크루 + 커뮤니티 | 100,000 |

---

## 수익 모델

- **Pro 구독**: 월 3,900원 / 연 29,000원 (무제한 사진·또래 비교·AI 캡션 등)
- **마켓 수수료**: 거래액의 3% (론칭 6개월 무료)
- **광고 없음**: 럭셔리 포지셔닝 유지, 직접 제휴만 허용

---

## 기여 & 라이선스

현재 1인 개발 프로젝트입니다. 버그 리포트나 피드백은 Issues를 통해 남겨주세요.

라이선스는 추후 확정 예정입니다. 사전 승인 없는 상업적 사용은 허용하지 않습니다.
