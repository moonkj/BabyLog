# BabyLog 디자인·화면 구성 검토 (DESIGN_REVIEW.md)

> 팀장(아키텍트) 작성 · 2026-06-10 · 입력: 디자인 핸드오프(`design/handoff/`) + `DESIGN.md` + `SPEC.md`

## 1. 프레임워크 결정 기록 (중요)

| 시점 | 결정 |
| --- | --- |
| 초기 | Flutter 검토 (핸드오프 README도 "개발 대상 Flutter" 명시) |
| 최종 | **Swift / SwiftUI로 확정** (오너 지시) |

- 사유: 사용자 요청 효과 = **리퀴드 글래스(iOS 26 느낌)**. 환경이 **Xcode 26.5 + iOS 26 SDK**라 SwiftUI `TabView`/`.glassEffect`로 **네이티브 Liquid Glass**를 그대로 사용 가능 → 가장 충실.
- 정합성: 원본 `SPEC.md`·`CLAUDE.md`·`DESIGN.md`(§8.6)가 SwiftUI 기준이라 자연스럽게 일치.
- 핸드오프의 Flutter 매핑(Drift/Isar, in_app_purchase 등)은 **무효화**, SPEC의 iOS 네이티브 스택(CoreData+CloudKit, StoreKit2, WidgetKit, Core ML, Swift Charts) 복귀.
- 핸드오프 React/JSX·CSS는 **픽셀·카피·레이아웃의 참조 소스**로만 사용(스타일 복붙 금지, SwiftUI 위젯으로 재구성).

## 2. 디자인 핸드오프 인벤토리 (`design/handoff/`)

| 자산 | 용도 |
| --- | --- |
| `README.md` | 토큰·IA·화면별 명세·인터랙션·상태모델 (핸드오프 단일 출처) |
| `design_files/babylog-ds.css` | 디자인 토큰 원본(색·타이포·간격·라운드·그림자·`.bl-liquid`) |
| `design_files/00 Design System.html` | 토큰·컴포넌트·뱃지·티어 쇼케이스 |
| `design_files/app/*.jsx` (13개) | 화면별 픽셀·카피·상태 로직 참조 |
| `design_files/feature_spec.txt` | 기능 스펙 v0.2 (요구사항) |
| `screenshots/*.png` | 홈 화면 시안 |
| `BabyLog App (standalone).html` | 3.2MB 인터랙티브 프로토타입 → git 제외(원본 Downloads 참조) |

## 3. 화면 구성 검토 (IA + 화면별)

**정보구조: 5탭 하단 네비** `홈 · 기록 · 동네 · 가계부 · 내정보` + **우하단 빠른 기록 FAB**(스피드다이얼, 홈·기록·동네에서만). SPEC 기능 8과 100% 일치 → ✅ 채택.

| 화면 | 핵심 구성 | 검토 의견 |
| --- | --- | --- |
| 홈 | 인사+응급 / 다자녀 칩 / 우선순위 엔진 단일 카드 / 하위 모듈 3~4 / 레이아웃 3안(A히어로·B대시보드·C타임라인) / 임신 전용 홈 | ✅ 단일 우선순위 카드 = 좋은 절제. 레이아웃 3안은 원격구성 플래그로(B-피처플래그). |
| 기록(육아) | 세그먼트 타임라인/성장차트/예방접종, 헤더 공유→성장카드 | ✅ 차트=Swift Charts. 백분위는 안심 메시지 기본·수치 옵트인(SPEC 14.2) 준수. |
| 기록(임신) | 태아 히어로 / 태동 카운터 / 체중추이 / 배사진 D라인 / 산전검사 / "출산했어요" 전환 | ⚠️ **Pregnancy→Child 승계 원자성**(B2)이 최대 리스크 — 전환 트랜잭션·롤백 선설계 필요. |
| 빠른기록 시트 | 사진 드롭존+이정표 칩+저장(2탭), 자세히 펼치기, 저장 보상 | ✅ "2탭 완료"가 1mm 지표. AI 캡션=Pro. |
| 동네/주변·응급 | 리스트 퍼스트(+지도), "○분 전 확인" 신뢰뱃지, 응급=별도 다크 풀스크린 초대형 전화 | ✅ 응급 다크 모드 별도 처리. 카카오맵 키 관리(B4) 주의. |
| 동네/마켓 | "곧 필요해요" 월령 추천, 상태등급 S/A/B/C, 리콜 경고, 판매=온디바이스 AI 분류 | ✅ 마일 이후(Supabase). v1 비포함. |
| 동네/크루 | 모임·또래 크루·게시판, 콜드스타트=기대감 UI(진행바·대기명단) | ✅ 밀도 미달 시 피처플래그 숨김. v3. |
| 가계부 | 정부지원금 전면, 도넛+카테고리, 자동수집 거래, 부부 공유 | ✅ 독립 탭 타당(지원금 핫). |
| 내정보 | 프로필카드(티어+보조뱃지3+통계4), Pro 업셀, 뱃지 컬렉션, 데이터·프라이버시 원칙 행 | ⚠️ 뱃지명 '골든 맘'→**'골든 맘/파파' 호칭 선택형**(A2 결정) 반영 필요. |
| 성장카드 공유 | 비율·데이터위치·표시토글·얼굴블러·워터마크, RepaintBoundary→이미지 | Swift: `ImageRenderer`로 대체(핸드오프의 Flutter `RepaintBoundary`↔). |
| 온보딩 | 스플래시→게스트 가치 미리보기→밀도 선택→임신/출산 분기→프리퍼미션, 강제입력 0 | ✅ 게스트 데이터 로컬→가입 시 마이그레이션. |

### 검토 리스크 요약
- **R1 (최고)**: 임신→출산 전환 원자성/롤백 + `Pregnancy.status` enum (B2).
- **R2**: 사진 타임라인 스크롤 성능 — 썸네일 사전생성·캐시(C2/P-1).
- **R3**: 외부 API 키(카카오맵 등) 관리 — v1 백엔드 없음(B4).
- **R4 (원칙)**: 내정보 뱃지명 성별중립(A2) — '골든 파파' 추가 반영.

## 4. 디자인 시스템 → Swift 매핑 (구현 완료, 빌드 ✅)

| 토큰/요소 | 구현 파일 |
| --- | --- |
| 색상(라이트·다크 적응) + 뱃지 7색 | `App/Sources/DesignSystem/AppColors.swift` |
| 타이포 스케일(9단계) | `AppTypography.swift` (Pretendard 번들은 TODO) |
| 간격/라운드/그림자 토큰 | `AppMetrics.swift` |
| **시그니처 Liquid Glass**(iOS26 `.glassEffect`+폴백) | `LiquidGlass.swift` |
| **시그니처 LiquidButton**(`.bl-liquid` 물 흐르는 빛 띠, reduce-motion 대응) | `Components/LiquidButton.swift` |
| 카드/뱃지/칩/섹션헤더/사진 플레이스홀더 | `Components/BLComponents.swift` |

## 5. 네비게이션 아키텍처 (구현 완료)

- `MainTabView`(5탭, iOS26 시스템 Liquid Glass 탭바) + `QuickRecordFAB`(스피드다이얼, 모드별 액션, 45° 회전) — `App/Sources/Shell/`
- 홈은 스크린샷 01-home 재현(인사·응급·다자녀칩·히어로·우선순위 골드카드·기록 권유). 나머지 탭은 디자인시스템 적용 골격.
- push/sheet 스택, 딥링크, IndexedStack(탭 상태 보존), baby/pregnancy 모드 전환은 후속 구현.

## 6. 다음 구현 단계 (Phase 3 본구현)

1. **B1 SPM 모듈 분리**: `BLCore`(이벤트버스·모델) / `BLDesignSystem` / 기능 모듈(`BLGrowth`·`BLInfra`·`BLPregnancy`). 현재는 단일 앱 타깃(빌드 우선).
2. **데이터 레이어**: CoreData 모델(Pregnancy/Child/GrowthRecord…) + Pregnancy→Child 승계(B2) + CloudKit.
3. **에셋**: Pretendard Variable 번들 + Dynamic Type, Asset Catalog named color 이관(DESIGN.md §2.4), 앱 아이콘.
4. **화면 본구현**: 홈 3레이아웃 → 기록(타임라인/차트/접종) → 빠른기록 시트 → 동네/주변·응급 → 온보딩.
5. **시그니처 모션 시스템**(DESIGN.md §8, 31 모티프 4계층)을 재사용 뷰로.
