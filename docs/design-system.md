# BabyLog 디자인 시스템 가이드

> 토큰 출처: `design/handoff/design_files/babylog-ds.css` (단일 진실 공급원)  
> Swift 구현: `App/Sources/DesignSystem/` · `App/Sources/Components/`  
> 최종 업데이트: 2026-06-10

---

## 1. 디자인 언어

**"Warm Ivory · Ink · Sage · Gold"** — 따뜻하고 신뢰할 수 있는 럭셔리 육아 앱. 순수 검정(#000)과 순수 흰색만의 차가운 느낌을 피하고 아이보리 베이스 위에 따뜻한 잉크 계열로 구성합니다.

---

## 2. 색상 토큰

### 2.1 라이트 / 다크 적응형

Swift 구현: `AppColors.swift` (UIColor dynamic provider 기반)

| 역할 | 토큰 | 라이트 | 다크 |
|---|---|---|---|
| 앱 배경 | `AppColors.canvas` | `#F4EFE6` | `#1A1A1C` |
| 카드/시트 | `AppColors.surface` | `#FFFFFF` | `#2A2A2D` |
| 인셋 영역 | `AppColors.surface2` | `#FBF7F0` | `#222226` |
| 눌림/트랙 | `AppColors.surface3` | `#F0EADE` | `#303035` |
| 본문 텍스트 | `AppColors.ink` | `#211D17` | `#F3EFE7` |
| 보조 텍스트 | `AppColors.ink2` | `#6B6256` | `#B8AFA0` |
| 3차/placeholder | `AppColors.ink3` | `#A89D8C` | `#8A8175` |
| 헤어라인 | `AppColors.line` | `#E9E1D3` | `#3A3A40` |
| 진한 구분선 | `AppColors.line2` | `#DBD1BF` | `#47474D` |
| 브랜드 주색 (sage) | `AppColors.primary` | `#4E8268` | `#8FBCA3` |
| 주색 눌림 | `AppColors.primaryPress` | `#3F6B55` | `#6FA386` |
| 주색 소프트 | `AppColors.primarySoft` | `#DCEFE6` | `#24443A` |
| 주색 틴트 | `AppColors.primaryTint` | `#E1F5EE` | `#1F3C33` |
| 골드 (Pro/골든티어) | `AppColors.gold` | `#B0832E` | `#D7A94E` |
| 골드 틴트 | `AppColors.goldTint` | `#FAEEDA` | `#37301E` |
| 위험/응급/리콜 | `AppColors.danger` | `#BE4D38` | `#E0735C` |
| 위험 틴트 | `AppColors.dangerTint` | `#FAE2DB` | `#38201A` |

### 2.2 고정 색상 (모드 무관)

| 역할 | 토큰 | HEX |
|---|---|---|
| 응급 모드 배경 | `AppColors.emergencyBg` | `#15110E` |
| 응급 모드 액션 | `AppColors.emergencyAction` | `#FF5C42` |
| 응급 모드 강조 | `AppColors.emergencyAccent` | `#FF8A72` |
| 임신 모드 핑크 | `AppColors.pregnancyPink` | `#B5478A` |

### 2.3 뱃지 카테고리 팔레트

7색 팔레트. **색 + 아이콘 + 레이블 3중 인코딩** 필수 (색만으로 정보 전달 금지).

Swift 구현: `BadgeTone` enum in `AppColors.swift` — `.bg` / `.ink` 프로퍼티 제공.

| 티어/카테고리 | `BadgeTone` | 배경 | 잉크 |
|---|---|---|---|
| 새싹 (신규) | `.grey` | `#F1EFE8` | `#877E6B` |
| 따뜻한 이웃 | `.mint` | `#E1F5EE` | `#2E7A5C` |
| 믿음직한 맘 | `.purple` | `#EEEDFE` | `#5B53B0` |
| 골든 맘/파파 | `.amber` | `#FAEEDA` | `#98711E` |
| 렌탈/위험 관련 | `.coral` | `#FAECE7` | `#B45840` |
| 임신/특별 | `.pink` | `#FBEAF0` | `#B5478A` |
| 커뮤니티 활동 | `.blue` | `#E6F1FB` | `#3B6FA8` |

---

## 3. 타이포그래피

폰트: **Pretendard Variable** (번들 예정. 현재는 시스템 폰트 근사).  
숫자(키·몸무게·날짜): tabular figures — `AppFont.num(_:weight:)` 사용.

Swift 구현: `AppFont` enum in `AppTypography.swift`

| 스타일 | Swift | 크기 | 행간 | 굵기 | 자간 |
|---|---|---|---|---|---|
| Display | `AppFont.display` | 34 / 40 | — | 800 (heavy) | -0.02em |
| H1 | `AppFont.h1` | 27 / 34 | — | 700 (bold) | -0.018em |
| H2 | `AppFont.h2` | 22 / 28 | — | 700 (bold) | -0.014em |
| Title | `AppFont.title` | 18 / 24 | — | 600 (semibold) | -0.01em |
| Body | `AppFont.body` | 16 / 24 | — | 400 (regular) | 0 |
| Callout | `AppFont.callout` | 15 / 22 | — | 400 (regular) | 0 |
| Subhead | `AppFont.subhead` | 14 / 20 | — | 500 (medium) | 0 |
| Caption | `AppFont.caption` | 13 / 18 | — | 500 (medium) | 0 |
| Micro | `AppFont.micro` | 11 / 14 | — | 700 (bold) | +0.06em, 대문자 |

---

## 4. 간격 · 라운드 · 그림자

### 4.1 간격 (4-base)

Swift 구현: `Spacing` enum in `AppMetrics.swift`

| 토큰 | 값 | CSS |
|---|---|---|
| `Spacing.s1` | 4pt | `--s1: 4px` |
| `Spacing.s2` | 8pt | `--s2: 8px` |
| `Spacing.s3` | 12pt | `--s3: 12px` |
| `Spacing.s4` | 16pt | `--s4: 16px` |
| `Spacing.s5` | 20pt | `--s5: 20px` |
| `Spacing.s6` | 24pt | `--s6: 24px` |
| `Spacing.s7` | 32pt | `--s7: 32px` |
| `Spacing.s8` | 40pt | `--s8: 40px` |
| `Spacing.s9` | 56pt | `--s9: 56px` |

### 4.2 라운드

Swift 구현: `Radius` enum in `AppMetrics.swift`

| 토큰 | 값 | 용도 |
|---|---|---|
| `Radius.xs` | 8pt | 인라인 요소 |
| `Radius.sm` | 12pt | 소형 컴포넌트 |
| `Radius.md` | 16pt | 버튼 |
| `Radius.lg` | 22pt | 카드 (기본) |
| `Radius.xl` | 28pt | 시트·모달 |
| `Radius.pill` | 999pt | 캡슐형 칩·뱃지 |

### 4.3 그림자 (따뜻한 톤)

Swift 구현: `.blShadow(_:)` View extension in `AppMetrics.swift`

| 토큰 | 용도 | CSS 원본 |
|---|---|---|
| `.chip` | 칩·행 | `0 1px 2px rgba(40,33,24,.05), 0 1px 1px rgba(40,33,24,.04)` |
| `.card` | 카드 | `0 2px 4px rgba(40,33,24,.05), 0 8px 20px rgba(40,33,24,.06)` |
| `.sheet` | 시트 | `0 4px 8px rgba(40,33,24,.06), 0 18px 40px rgba(40,33,24,.10)` |
| `.fab` | FAB·리퀴드 버튼 | `0 6px 16px rgba(78,130,104,.32), 0 2px 5px rgba(40,33,24,.12)` |

---

## 5. 컴포넌트 사용법

### 5.1 BLCard

기본 카드. 반경 22pt, 패딩 18pt, 카드 그림자.

```swift
// 기본 카드 (그림자 있음)
BLCard {
    VStack(alignment: .leading, spacing: 8) {
        Text("제목").font(AppFont.title).foregroundStyle(AppColors.ink)
        Text("설명").font(AppFont.caption).foregroundStyle(AppColors.ink2)
    }
}

// 플랫 카드 (헤어라인 테두리, 그림자 없음)
BLCard(flat: true) {
    Text("플랫 카드")
}
```

### 5.2 BLBadge

뱃지/티어 칩. 색 + 아이콘(선택) + 레이블 3중 인코딩.

```swift
// 아이콘 + 텍스트
BLBadge(tone: .amber, text: "골든 맘", systemIcon: "crown.fill")

// 도트 + 텍스트 (기본)
BLBadge(tone: .mint, text: "나눔 천사")

// 도트 없음
BLBadge(tone: .purple, text: "육아고수", dot: false)
```

### 5.3 BLChip

필터 칩. 온/오프 상태.

```swift
@State private var selected = false

BLChip(text: "현재 영업중", on: selected) {
    selected.toggle()
}
```

### 5.4 LiquidButton

시그니처 리퀴드 CTA 버튼. 저장·전화·시작 등 주요 채움 버튼에만 사용.

```swift
// 기본 (sage 색상)
LiquidButton(action: { /* 저장 */ }) {
    Text("저장하기")
}

// 골드 (Pro·접종 예약 등)
LiquidButton(fill: AppColors.gold, action: { /* 예약 */ }) {
    Text("접종 예약하기")
}

// 아이콘 포함
LiquidButton(action: { /* 전화 */ }) {
    Label("전화하기", systemImage: "phone.fill")
}
```

### 5.5 liquidGlass (뷰 수정자)

iOS 26 네이티브 Liquid Glass. 메뉴·시트·툴바·헤더 등 chrome 표면에 사용. iOS 25 이하에서는 `.ultraThinMaterial`로 자동 폴백.

```swift
// iOS 26 Liquid Glass 적용
someView
    .liquidGlass(cornerRadius: Radius.lg)

// 탭뷰 시스템 탭바는 iOS 26에서 자동 Liquid Glass 적용
// (별도 코드 불필요)
```

### 5.6 BLSectionHead

섹션 헤더. 눈썹(eyebrow) + 타이틀 + 액션.

```swift
BLSectionHead(
    eyebrow: "이번 달",
    title: "예방접종 일정",
    action: "전체 보기",
    onAction: { /* 이동 */ }
)
```

### 5.7 PhotoPlaceholder

따뜻한 그라데이션 사진 플레이스홀더. seed 값으로 6가지 색상 순환.

```swift
PhotoPlaceholder(seed: childIndex, cornerRadius: Radius.lg)
    .frame(height: 200)
```

---

## 6. 시그니처 리퀴드 효과

### 6.1 LiquidButton 내부 구조

두 레이어가 겹쳐 "물 흐르는" 느낌을 만듭니다.

```
[ 버튼 배경 (fill 색) ]
    + 광택 메니스커스 (항상):
        RadialGradient(상단 radial 하이라이트, rgba(255,255,255,.34))
    + 흐르는 빛 띠 (애니메이션):
        LinearGradient 50% 폭 흰 띠
        → offset -50% ~ 128%, skewX -14°, blur 3px
        → 4.6s 루프 (누르면 1.1s 가속)
        → prefers-reduced-motion 시 비활성
```

`@Environment(\.accessibilityReduceMotion)` 자동 대응이 구현에 포함되어 있습니다.

### 6.2 liquidGlass 폴백 체계

```swift
if #available(iOS 26.0, *) {
    self.glassEffect(.regular, in: shape)   // 네이티브 Liquid Glass
} else {
    self.background(.ultraThinMaterial, in: shape)  // 폴백
}
```

---

## 7. 접근성 설계 원칙

BabyLog는 접근성을 나중에 소급하지 않고 **처음부터 내재화**합니다. 소급 적용 시 전면 재작업이 발생합니다.

### 7.1 색 + 아이콘 + 레이블 3중 인코딩

색만으로 정보를 전달하지 않습니다. 뱃지·상태·알림 모든 곳에 적용.

```swift
// 올바른 예: 색(mint bg) + 아이콘(clock) + 레이블("영업중") 3중
BLBadge(tone: .mint, text: "영업중", systemIcon: "clock.fill")

// 잘못된 예: 색만으로 영업 상태를 나타내는 것은 금지
```

### 7.2 Dynamic Type

`AppFont`의 모든 폰트는 `Font.system(size:weight:)` 기반이므로 시스템 글씨 크기 설정에 자동 반응합니다. Pretendard 번들 후에도 `relativeTo:` 매핑을 유지합니다.

### 7.3 VoiceOver

- 모든 인터랙티브 요소에 `.accessibilityLabel` 명시
- `QuickRecordFAB`의 주 버튼: `.accessibilityLabel("빠른 기록")`
- 아이콘만 있는 버튼은 반드시 레이블 추가

```swift
Button { } label: {
    Image(systemName: "bell.fill")
}
.accessibilityLabel("알림 설정")
```

### 7.4 히트 타깃

최소 44×44pt. `frame(width: 44, height: 44)` 또는 `.contentShape(Rectangle())` 사용.

### 7.5 응급 모드 접근성

응급 모드(고대비 다크)는 새벽·불안한 상황에서의 접근성을 최우선으로 설계합니다.
- 전화 버튼을 최대 크기로
- 필터 없이 즉시 결과 노출
- 최소 정보만 표시

---

## 8. 모션 & 인터랙션

| 이름 | 값 | 용도 |
|---|---|---|
| ease | `cubic-bezier(.22,.61,.36,1)` | 일반 전환 |
| ease-out | `cubic-bezier(.16,1,.3,1)` | 슬라이드업·팝 |
| fadeIn | 0.2s | 컴포넌트 등장 |
| slideUp | 0.3s ease-out | 바텀시트 |
| pushIn | 0.28s ease-out | 화면 푸시 |
| pop (저장 보상) | 0.5s | 기록 저장 후 애니메이션 |
| fabIn | 0.2s stagger | 스피드다이얼 펼침 |
| 리퀴드 플로우 | 4.6s 루프 | LiquidButton 빛 띠 |

눌림 피드백: 주요 카드·버튼 `scale(0.975~0.97)` — `LiquidPressStyle` 사용.
