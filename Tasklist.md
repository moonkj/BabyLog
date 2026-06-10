# BabyLog 작업 추적 (Tasklist.md)

> 팀장과 모든 팀원이 전체 진행 상황을 함께 추적하는 단일 보드.
> 상태: ⬜ 대기 / 🔵 진행중 / ✅ 완료 / 🟡 블록(의존 대기) / 🔴 문제

마지막 갱신: 2026-06-10 (Swift 확정 · 디자인 검토 · 파운데이션 빌드 성공) · 갱신자: lead

---

## 진행 단계 개요

| Phase | 내용 | 상태 |
| --- | --- | --- |
| Phase 0 | 팀 세팅 & 스펙 확인 | ✅ 완료 |
| Phase 1 | 디자인 검토 & UX (핸드오프 + DESIGN.md) | ✅ 완료 → [DESIGN_REVIEW](team/DESIGN_REVIEW.md) |
| Phase 2 | 아키텍처 (프레임워크=**Swift/SwiftUI 확정**, 디자인시스템·셸) | 🔵 진행 (SPM 모듈화 B1 잔여) |
| Phase 3 | v1 MVP 구현 — 파운데이션 빌드 성공, 본구현 병렬 진행 | 🔵 진행 |
| Phase 4 | 디버그 → 테스트 → 성능 → 리뷰 사이클 | ⬜ 대기 |
| Phase 5 | 문서화 & 릴리즈 준비 | ⬜ 대기 |

---

## Phase 0 — 팀 세팅 & 스펙 확인 (현재)

| # | 작업 | 담당 | 상태 |
| --- | --- | --- | --- |
| 0.1 | git 초기화 + 팀 조정 파일 생성 (TEAM/Tasklist/process) | lead | ✅ |
| 0.2 | 스펙(CLAUDE.md·SPEC.md) 팀장 정독·확인 | lead | ✅ |
| 0.3 | 스펙 확인 — Coder 관점 → [coder.md](team/confirmations/coder.md) | coder | ✅ |
| 0.4 | 스펙 확인 — Debugger 관점 → [debugger.md](team/confirmations/debugger.md) | debugger | ✅ |
| 0.5 | 스펙 확인 — QA 관점 → [qa.md](team/confirmations/qa.md) | qa | ✅ |
| 0.6 | 스펙 확인 — Perf/Doc 관점 → [perf-doc.md](team/confirmations/perf-doc.md) | perf-doc | ✅ |
| 0.7 | 팀장 통합 (오픈 질문 취합·로그 정리) | lead | ✅ |
| 0.8 | 디자인 파일 수령 → Phase 1 트리거 | lead | 🟡 대기 |

---

## 토론 로그 (과학적 토론)
<!-- [주제] 측면별 발견 → 공유/반박 → 결론 -->
- **[T1] 원칙 충돌: 무광고 vs v3 배너 광고** — qa 발견. CLAUDE.md '무광고'(광고 SDK 미도입) ↔ SPEC v3 '육아 브랜드 배너 광고(직계약)'. 팀장 견해: '무광고'의 핵심은 프로그래매틱/광고SDK 차단이고 SPEC 수익원칙도 '직접 제휴만 허용'이라 직계약 노출은 형식상 양립 가능하나 '배너' 형태가 럭셔리 포지셔닝과 상충 가능. **v1 비차단 사안, 오너 최종 결정 대기(A1).**
- **[T2] 원칙 충돌: 성별 중립 vs 뱃지명 '골든 맘'** — qa 발견. SPEC 7.2 뱃지명('골든 맘')이 SPEC B.5 '성별 중립(맘/파파 선택)'·CLAUDE.md 절대원칙과 충돌. → **[오너 결정] ✅ 해소: 골든 파파 추가 — 최상위 티어를 '골든 맘/골든 파파' 호칭 선택형(중립 옵션 가능), SPEC 7.2 반영 완료 (A2).**

## 교차 영향 로그 (Cross-Layer)
<!-- [영향] 출처→대상: 변경내용 → 필요 조치 -->
- **[X1] lead→all: SPM 경계/CoreData 스택 소유(B1) 확정이 모든 구현의 선결.** BLData가 persistent container 단독 소유, 기능 패키지 간 직접 의존 금지(이벤트버스 경유). Phase 2에서 팀장 확정 예정.
- **[X2] lead→coder·debugger·qa: Pregnancy.status enum(B2) 정의가 전환 로직·테스트·민감영역 모드에 동시 전파.** 정의 전까지 관련 구현 보류.
- **[X3] perf-doc→coder: 사진 저장 시점 썸네일 사전 생성·이중 캐시 구조 필요(P-1)** → GrowthRecord/DiaryEntry 저장 파이프라인에 썸네일 단계 포함 설계 요망(디자인 수령 후 크기 확정).
- **[X4] lead→all: 스펙 v0.2 — 5탭 IB(홈·기록·동네·가계부·내정보) + 우상단 FAB 확정.** 기능 8(정보구조&네비) 신설, 기존 8~14 → 9~15 재번호. UX 와이어프레임·코더 화면 골격에 직접 영향 → Phase 1 착수 시 **5탭 셸 + 우상단 FAB 컴포넌트 우선 설계**, 동네 탭은 주변/마일/크루 세그먼트.

## 가설 검증 로그 (Hypothesis)
<!-- [가설 Hn] 담당: 가설 → 검증결과(기각/채택) + 근거 -->
- (현재 버그 없음 — 잠재 버그 가설 씨앗은 [debugger.md](team/confirmations/debugger.md) 참조, 구현 중 활성화)

## 오픈 질문 (디자인/스펙 확정 필요)

### A. 오너(제품) 판단 [원칙 층위]
- **A1.** 〔보류·추후 적용〕 무광고 절대원칙 vs v3 '브랜드 배너 광고(직계약)' — 추후 결정, v1 비차단
- **A2.** ✅ 〔결정 완료〕 골든 파파 추가 — 최상위 티어 '골든 맘/골든 파파' 호칭 선택형(중립 옵션 가능), SPEC 7.2 반영

### B. Phase 2 아키텍처 확정 — 팀장(아키텍트) 결정 예정 [v1 코드 선결]
- **B1.** SPM 모듈 경계 + CoreData 스택 소유 구조 (제안: BLCore→BLData→BLGrowth/BLInfra/BLPregnancy)
- **B2.** Pregnancy.status enum 정의(.active/.delivered/.loss/.paused) + 전환 원자성·롤백 전략
- **B3.** CloudKit 동시편집 충돌 정책(부부 동시입력 무음소실 방지) + 가족공유 해제 후 데이터 처리
- **B4.** 외부 API 키 관리(v1 백엔드 없음 → 최소 서버 프록시 vs 번들 stopgap)

### C. 디자인 파일 수령 후 확정 — Phase 1
- **C1.** 임신 배사진 ↔ 성장사진 혼합 타임라인 시각 구분 UI
- **C2.** 썸네일 크기 기준(P-1) / 성장카드 템플릿 레이아웃·비율
- **C3.** 5탭 셸 + 우상단 FAB 비주얼/아이콘, 동네 탭 세그먼트 레이아웃 (X4 연계)

### D. 계산 컨벤션 — ✅ 유지·확정 (팀장 기본값)
- **D1.** 임신 주수: LMP 기준 산출, 초음파 보정 EDD 입력 시 EDD 우선 / 'D+주차' 표기
- **D2.** 월령: Calendar 기반 개월수(생후 N개월) + D+N일 병기
- **D3.** '기록 멈춤': 사용자 토글 강제 X, 미접속 자동 감지로 권유 알림 '자동 억제' + 따뜻한 수동 진입점. 임계값 **미접속 30일** (확정)

---

## Phase 3 병렬 작업 (진행중 · 2026-06-10)

> 팀장이 백그라운드 병렬 디스패치 → 완료 시 통합 빌드·검증. 충돌 방지로 디렉토리 분리.

| 담당 | 작업 | 산출물 | 상태 |
| --- | --- | --- | --- |
| coder | Core+Data (AgeCalculator·Models·PregnancyTransition·EventBus) | `App/Sources/Core·Data` | ✅ 빌드 검증 |
| qa | 단위 테스트 27개 (계산·승계 검증) | `Tests/BabyLogTests` | ✅ 27/27 통과 |
| debugger | Phase 3 리스크 감사 (A~E + 가설 H1~H5) | `team/debug/phase3-risk-audit.md` | ✅ 완료 |
| perf-doc | README + 기술문서 3종 | `README.md`·`docs/` | ✅ 완료 |

- **교차레이어 계약**: coder↔qa가 `AgeCalculator`/`PregnancyTransition` API 시그니처 공유 → 정합 보장 ✅
- **✅ 통합 결과**: test 타깃 추가 → `xcodegen` → `xcodebuild test` → **27/27 PASS**
- **과학적 토론(해소)**: QA 테스트가 이름 검증 결함(`"\n"` 통과) 적발 → `.whitespacesAndNewlines` 수정 → 녹색
- **디버거 후속 과제**: 상실 알림 차단 · 전환 원자성(B2) · AgeCalculator UTC 정규화 · ink3 대비 → Phase 3 본구현 트래킹
