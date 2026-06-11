# 백엔드·키 연동 가이드 (버킷 B)

> 마지막 갱신: 2026-06-10
> 대상: 앱 소유자(키/계정 보유자). 코드는 모두 준비돼 있고, **아래 값만 넣으면 해당 기능이 자동으로 켜진다.**
> 설계 원칙: 키 없으면 Mock 폴백으로 정상 동작(B4 정책). 절대 실제 키를 소스에 커밋하지 않는다.

---

## 1. 외부 API 키 (전부 무료 발급)

`APIConfig.key(_:)`가 **① 프로세스 환경변수 → ② Info.plist** 순으로 키를 읽는다.
키가 있으면 `ProviderFactory`가 자동으로 Live 프로바이더로 전환되고, 없으면 Mock 데이터를 보여준다.

### 1.1 키 이름 (Info.plist 커스텀 엔트리)

| Info.plist 키 | 용도 | 발급처 |
|---|---|---|
| `KAKAO_REST_API_KEY` | 주변 장소·병원 POI 검색 | [developers.kakao.com](https://developers.kakao.com) → 앱 → REST API 키 |
| `HIRA_API_KEY` | 소아과/약국 정보(심평원) | [data.go.kr](https://www.data.go.kr) → 건강보험심사평가원 |
| `BOKJIRO_API_KEY` | 정부지원금(복지로) | [data.go.kr](https://www.data.go.kr) → 복지로 |
| `KDCA_VACCINE_API_KEY` | 예방접종 표준 일정(질병관리청) | [data.go.kr](https://www.data.go.kr) → 예방접종도우미 |

### 1.2 적용 방법 (권장: Build Settings 주입)

1. **xcconfig 또는 Build Settings**에 사용자 정의 빌드 설정 추가 (예: `KAKAO_REST_API_KEY = <발급키>`).
   - 키 파일은 `.gitignore`에 두고 절대 커밋하지 않는다.
2. **App/Resources/Info.plist**에 엔트리 추가 (값은 빌드 설정 참조):
   ```xml
   <key>KAKAO_REST_API_KEY</key>
   <string>$(KAKAO_REST_API_KEY)</string>
   <key>HIRA_API_KEY</key>
   <string>$(HIRA_API_KEY)</string>
   <key>BOKJIRO_API_KEY</key>
   <string>$(BOKJIRO_API_KEY)</string>
   <key>KDCA_VACCINE_API_KEY</key>
   <string>$(KDCA_VACCINE_API_KEY)</string>
   ```
   > 현재 Info.plist에는 이 엔트리가 없다(= 항상 Mock). 위 4줄을 추가하고 빌드 설정에 키를 넣으면 Live 전환.
3. 빌드 후 확인: 주변(병원), 가계부(지원금), 기록(접종)이 실데이터로 채워지면 성공.

### 1.3 키 없이도 정상

키 미설정 시 각 화면은 Mock 샘플을 보여주고 크래시 없이 동작한다. CI/QA는 키 없이 빌드·테스트한다.

---

## 2. App Group — 위젯 실데이터

코드 경로는 이미 상주한다 (`CodablePersistence.appGroup()`, `WidgetSnapshot.loadSharedChild()`).
**유료 개발자 프로그램 + App Group Capability 등록**이 필요하다(무료 계정 불가).

1. Apple Developer 포털에서 App Group `group.com.babylog.app` 등록, 두 App ID(앱·위젯)에 연결.
2. **project.yml**에서 두 타깃의 엔타이틀먼트 주석 해제:
   ```yaml
   # BabyLog 타깃
   CODE_SIGN_ENTITLEMENTS: App/Resources/BabyLog.entitlements
   # BabyLogWidget 타깃
   CODE_SIGN_ENTITLEMENTS: Widget/BabyLogWidget.entitlements
   ```
   (엔타이틀먼트 파일은 이미 존재하며 `group.com.babylog.app`를 포함)
3. `xcodegen generate` → 빌드. 위젯이 실제 첫 아이 데이터를 표시한다.

> 미적용 시: `containerURL`이 nil → 자동으로 일반 컨테이너로 폴백, 위젯은 목업 표시. 앱은 정상.

---

## 3. CloudKit — 가족 백업·공유 (스캐폴드 준비됨)

조부모 등 가족이 **다른 기기에서 사진·영상·기록을 보려면 클라우드 동기화가 필수**다(로컬 저장만으론 부모 기기에서만 보임). CloudKit 동기화 코드가 이미 들어가 있고, **유료 계정 연결 + 플래그만** 켜면 활성화된다.

구현 방식: `CloudSyncService`가 전체 상태(`PersistableState`)를 **개인 CloudKit DB의 단일 레코드(JSON)**로 push/pull(last-write-wins). 앱 규모상 충분하며, 추후 per-record + `CKShare`(가족 공유)로 확장 가능.

### 활성화 절차 (유료 Apple Developer 필요)
1. **Apple Developer 포털**에서 iCloud 컨테이너 `iCloud.com.babylog.app` 생성 + 앱 App ID에 **iCloud(CloudKit)** Capability 연결.
2. **project.yml** (BabyLog 타깃) 주석 해제:
   ```yaml
   CODE_SIGN_ENTITLEMENTS: App/Resources/BabyLog.entitlements   # iCloud/CloudKit 키 포함
   SWIFT_ACTIVE_COMPILATION_CONDITIONS: $(inherited) BL_CLOUDKIT  # CloudKit 코드 컴파일
   ```
   (엔타이틀먼트 파일에 `icloud-container-identifiers`·`icloud-services=CloudKit` 이미 포함)
3. `xcodegen generate` → 빌드. **설정 > iCloud 가족 백업**에 자동백업 토글 + "지금 백업/복원" 노출, 동작.

### 동작 / 정책
- 미활성(현재): `BL_CLOUDKIT` 없음 → `CloudSyncService`가 CKContainer를 절대 호출하지 않음(빌드/실행 안전). 설정엔 "준비됨" 안내만 표시.
- 활성 후: 무료=로컬, **iCloud 가족 백업=Pro**(CLAUDE.md 사진 비전송·서버백업 Pro 정책과 일치).
- 가족(조부모) 공유: 같은 iCloud 계정 → 즉시 동기화. 별도 계정 가족은 `CKShare` 확장 단계에서 지원.

---

## 4. StoreKit 2 — Pro 구독

Pro 게이트 위치(현재 정직한 "곧 만나요" 안내 또는 false 고정):

| 위치 | 현재 동작 | 연동 후 |
|---|---|---|
| `ProfileScreen` Pro 업셀/7일 무료 버튼 | `showProDetail` 안내 알림 | StoreKit 구매 플로우 |
| `ShareCardView.isPro` (false 고정) | 워터마크 제거 잠금 | 구매 상태 주입 |
| `QuickRecordSheet` AI 캡션 버튼 | "곧 제공" 알림 | 서버 LLM 호출(Pro) |

1. App Store Connect에서 구독 상품 등록(월간 3,900 / 연간 29,000 — 화면 표기 기준).
2. `StoreKit 2` `Product.products(for:)` + `purchase()` 도입, 구매 상태를 `isPro`로 앱 전역 주입.
3. 정직 결제 원칙(CLAUDE.md): 자동결제 사전 고지, 해지 쉬움, 다크패턴 금지.

---

## 5. Supabase — 마켓·크루 (미구축)

중고 마켓 거래/채팅, 동네 크루 게시/가입은 백엔드가 필요하다(현재 UI만 존재, 로컬 상호작용은 데모).

- Postgres + Auth + Storage + Realtime.
- 연동 지점: `MarketScreen`/`MarketItemDetail`/`MarketChatSheet`, `CrewScreen`(콜드스타트→활성).
- 사진 정책(CLAUDE.md): 아동 사진은 서버 업로드 금지(무료), 서버 백업은 Pro 한정.

---

## 우선순위 제안

1. **카카오 REST 키** — 가장 즉효(주변 병원 실검색), 무료, Info.plist 4줄.
2. **나머지 공공데이터 키**(심평원·복지로·질병청) — 접종/지원금 실데이터.
3. **App Group**(유료 계정 시) — 위젯 실데이터, project.yml 2줄.
4. StoreKit / CloudKit / Supabase — 별도 개발 단계.
