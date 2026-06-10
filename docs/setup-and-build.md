# BabyLog 환경 설정 & 빌드 가이드

> 최종 업데이트: 2026-06-10

---

## 1. 요구사항

| 도구 | 버전 | 비고 |
|---|---|---|
| **Xcode** | **26.5 이상** | iOS 26 SDK 필요 (Liquid Glass `.glassEffect` 네이티브 지원) |
| Swift | 5.0 이상 | `project.yml` `SWIFT_VERSION: "5.0"` |
| **XcodeGen** | 최신 권장 | `.xcodeproj`를 `project.yml`에서 생성. **필수** |
| macOS | Sequoia 이상 | Xcode 26.5 호환 버전 |

> `.xcodeproj` 파일은 버전 관리에 포함하지 않습니다. 반드시 클론 후 `xcodegen generate`를 실행하세요.

---

## 2. 첫 설정 절차

### 2.1 XcodeGen 설치

```bash
# Homebrew로 설치 (권장)
brew install xcodegen

# 설치 확인
xcodegen --version
```

### 2.2 저장소 클론

```bash
git clone <repo-url>
cd BabyLog
```

### 2.3 프로젝트 파일 생성

```bash
xcodegen generate
```

실행 후 `BabyLog.xcodeproj`가 생성됩니다.

### 2.4 Xcode에서 열기

```bash
open BabyLog.xcodeproj
```

Xcode에서 시뮬레이터 또는 실기기를 선택해 실행합니다.

---

## 3. CLI 빌드

### 3.1 시뮬레이터 빌드 (서명 없이)

개발 초기 또는 CI 환경에서 코드 서명 없이 빌드합니다.

```bash
xcodebuild \
  -scheme BabyLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 3.2 특정 iOS 버전 시뮬레이터

```bash
xcodebuild \
  -scheme BabyLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=17.0' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 3.3 Release 빌드 (아카이브)

```bash
xcodebuild \
  -scheme BabyLog \
  -configuration Release \
  archive \
  -archivePath build/BabyLog.xcarchive
```

---

## 4. 프로젝트 구성 (`project.yml`)

`project.yml`이 프로젝트 단일 출처입니다. 직접 수정 후 `xcodegen generate`를 다시 실행해야 합니다.

```yaml
name: BabyLog
options:
  bundleIdPrefix: com.babylog
  deploymentTarget:
    iOS: "17.0"         # 최소 배포 타깃
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "0.1.0"
    DEVELOPMENT_TEAM: ""        # 팀 ID는 로컬에서 설정
targets:
  BabyLog:
    type: application
    platform: iOS
    sources:
      - App/Sources
```

> **DEVELOPMENT_TEAM**: 개인 Apple Developer 계정 Team ID를 로컬에서 직접 입력합니다. 저장소에 커밋하지 마세요.

---

## 5. 테스트 실행

```bash
# 단위 테스트
xcodebuild test \
  -scheme BabyLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO

# 특정 테스트 클래스만 실행
xcodebuild test \
  -scheme BabyLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:BabyLogTests/PregnancyTransitionTests \
  CODE_SIGNING_ALLOWED=NO
```

테스트 타깃 경로: `Tests/`

---

## 6. 자주 묻는 문제 (FAQ)

### Q. `xcodegen generate` 후 빌드가 안 돼요

```bash
# .xcodeproj 삭제 후 재생성
rm -rf BabyLog.xcodeproj
xcodegen generate
```

### Q. "No such module 'SwiftUI'" 오류가 나요

Xcode 버전을 확인하세요. iOS 26 SDK가 포함된 **Xcode 26.5 이상**이 필요합니다.

```bash
xcodebuild -version
# Xcode 26.5 이상이어야 함
```

### Q. 코드 서명 오류가 발생해요 (시뮬레이터)

시뮬레이터 빌드 시 `CODE_SIGNING_ALLOWED=NO`를 반드시 추가합니다.

```bash
xcodebuild ... CODE_SIGNING_ALLOWED=NO build
```

### Q. 실기기 빌드 시 서명이 필요해요

`project.yml`에 본인 Apple Developer Team ID를 입력하거나 Xcode의 Signing & Capabilities에서 팀을 선택합니다. `DEVELOPMENT_TEAM`은 저장소에 커밋하지 않습니다.

### Q. `glassEffect` 관련 컴파일 오류가 나요

iOS 26 SDK가 없는 환경입니다. `LiquidGlass.swift`의 `#available(iOS 26.0, *)` 분기 덕분에 iOS 17+ 시뮬레이터에서도 빌드됩니다 (`.ultraThinMaterial` 폴백). Xcode 버전을 올려주세요.

### Q. `project.yml` 변경 후 Xcode가 변경을 인식 못해요

파일을 변경했다면 반드시 `xcodegen generate`를 다시 실행한 뒤 Xcode를 재시작합니다.

```bash
xcodegen generate
# 이후 Xcode 재시작
```

### Q. 빌드는 됐는데 탭바가 Liquid Glass로 안 보여요

Xcode 26 + iOS 26 시뮬레이터에서만 네이티브 Liquid Glass 탭바가 표시됩니다. iOS 17 시뮬레이터에서는 기존 스타일로 폴백됩니다.

---

## 7. 개발 환경 권장 설정

### Xcode 설정

- **Editor > Indentation**: Spaces, Width 4
- **Derived Data** 경로를 프로젝트 상대 경로로 설정하면 팀 간 일관성이 높아집니다.

### Git 설정

`.xcodeproj`는 `.gitignore`에 포함되어 있습니다 (또는 포함해야 합니다). `project.yml`만 버전 관리합니다.

```gitignore
# .gitignore 예시
BabyLog.xcodeproj/
*.xcworkspace/
DerivedData/
.build/
```

---

## 8. 빌드 타깃 구조

```
BabyLog (application)          — 메인 앱
  └─ App/Sources/              — 소든 Swift 소스

BabyLogTests (unit test)       — 단위 테스트
  └─ Tests/                    — 테스트 소스
```

배포 타깃은 **iOS 17.0**이지만 iOS 26 API는 `#available` 분기로 안전하게 사용합니다.

---

## 9. TestFlight & 배포

```bash
# 1. 아카이브
xcodebuild archive \
  -scheme BabyLog \
  -configuration Release \
  -archivePath build/BabyLog.xcarchive

# 2. IPA 내보내기 (ExportOptions.plist 필요)
xcodebuild -exportArchive \
  -archivePath build/BabyLog.xcarchive \
  -exportPath build/IPA \
  -exportOptionsPlist ExportOptions.plist

# 3. Transporter 또는 altool로 App Store Connect 업로드
xcrun altool --upload-app \
  -f build/IPA/BabyLog.ipa \
  -u <apple-id> \
  -p <app-specific-password>
```

> 배포는 원격 구성(피처 플래그)을 활용해 동네별 기능을 점진 개방합니다. 심사 없이 핫픽스가 필요한 범위는 피처 플래그로 처리합니다.
