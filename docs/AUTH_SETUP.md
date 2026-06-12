# Sign in with Apple → Supabase Auth 셋업 & 구현 계획

크루(동네) 백엔드는 지금 **익명 기기 UUID**(`bl_device_id`, UserDefaults) + **anon key**로만 동작한다.
글·모임·댓글의 소유권은 `author`/`host`/`creator`/`device_id` 컬럼(전부 `text`)으로만 구분하고,
RLS는 `using (true) with check (true)`로 누구나 모든 행을 읽고/쓰고/지울 수 있는 **MVP 상태**다.

이 문서는 그 위에 **Sign in with Apple → Supabase Auth(GoTrue)**를 얹어
"본인 글만 수정/삭제", "기기 바꿔도 내 콘텐츠 유지"를 만드는 구체 절차다.

- 대상 코드: `App/Sources/Networking/CrewBackend.swift`(`SupabaseConfig`, `request()`), `App/Sources/Networking/APIConfig.swift`
- 대상 스키마: `supabase/schema_crew.sql`
- 진입점: `App/Sources/Features/Onboarding/OnboardingView.swift`(이미 "이미 계정이 있어요" 버튼 존재, 현재는 `onComplete()`만 호출)
- Team ID `QN975MTM7H` · Bundle `com.vibelab.babylog` · 유료 프로그램 · APNs 이미 구성됨

> ⚠️ **이 문서는 계획서다. 코드/스키마를 자동 변경하지 않는다.** 아래 SQL/Swift는 적용 대상 스니펫이며, 실제 반영은 단계별 롤아웃 체크리스트(7장)를 따른다.

---

## 0. 왜 SDK 없이 가는가 (요약)

현재 모든 호출이 `URLSession` + PostgREST 직접 호출이다(`CrewBackend.request()` 한 군데에서
`apikey`/`Authorization: Bearer <anon>` 헤더를 붙인다). Apple 로그인도 **GoTrue REST 한 엔드포인트**
(`/auth/v1/token?grant_type=id_token`)만 추가하면 되므로 **supabase-swift SDK 없이 충분**하다.
SDK는 의존성·빌드 시간·"Apple 시스템 프레임워크만 사용" 포지셔닝(`SettingsScreen.swift`의 오픈소스 고지)을
깨므로 **REST 직결을 권장**한다. 트레이드오프는 3장 끝에 정리.

---

## 1. Apple Developer Console

> 유료 프로그램이라 모두 가능. (Sign in with Apple는 무료 팀에선 막혀 있음 — 이미 유료라 OK)

### 1-1. App ID에 capability 켜기 (필수)
1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → `com.vibelab.babylog`
2. **Sign In with Apple** 체크 → (Enable as a primary App ID) → **Save**
   - 이미 켜둔 **Push Notifications**와 공존 가능.
3. 앱 entitlement에 `com.apple.developer.applesignin` 추가가 필요(아래 2-3 / 6장 참고).

### 1-2. Service ID + Key — **네이티브 iOS만이면 생략 가능**
- **네이티브 `ASAuthorizationAppleIDProvider`**만 쓰고, 토큰 검증을 Supabase에 맡기면
  Supabase는 **App ID(=Bundle ID `com.vibelab.babylog`)를 Authorized Client로 등록**하는 것만으로 동작한다.
  → **Service ID 불필요, Sign in with Apple 전용 .p8 key 불필요.** (가장 단순한 경로, 권장)
- **Service ID + Key가 필요한 경우**: 웹/안드로이드(향후 KMP/Flutter) OAuth 리다이렉트 플로우를 쓸 때.
  그때는:
  1. Identifiers → **Services IDs** → `+` → 식별자 예 `com.vibelab.babylog.web` 생성 → Sign In with Apple 구성에서
     Return URL = `https://<프로젝트ref>.supabase.co/auth/v1/callback` 등록.
  2. Keys → `+` → **Sign in with Apple** 체크 → .p8 다운로드(1회) + **Key ID** 메모.
  3. 이 Key + Team ID + Service ID로 Supabase가 **client secret(JWT)**을 자동 생성/갱신.

### 1-3. Supabase에 넣을 값(경로별)
| 경로 | Supabase에 넣는 값 |
| --- | --- |
| 네이티브 전용(권장) | Apple provider 켜고 **Authorized Client IDs = `com.vibelab.babylog`** |
| 웹/멀티플랫폼 추가 | 위 + Service ID, Team ID `QN975MTM7H`, Key ID, .p8 내용 |

---

## 2. Supabase Dashboard

### 2-1. Apple provider 활성
1. Authentication → **Providers → Apple** → Enable.
2. **네이티브 전용(권장)**: 아래 "Authorized Client IDs"에 `com.vibelab.babylog` 입력(쉼표로 복수 가능).
   Secret 관련 칸은 비워도 native id_token 교환은 동작.
3. **웹/멀티플랫폼**: Services ID, Team ID, Key ID, .p8(또는 Supabase가 생성한 secret) 입력.

### 2-2. 리다이렉트 / 리턴 설정
- 네이티브 `id_token` 교환에는 redirect가 **불필요**(브라우저 왕복이 없음).
- 웹 OAuth를 추가할 때만 Authentication → URL Configuration에 Site URL / Redirect URLs(예 앱 커스텀 스킴
  `babylog://auth-callback`)를 등록.

### 2-3. 앱 entitlement (참고, 6장에서 실제 작업)
현재 활성 entitlements는 `App/Resources/BabyLog.push.entitlements`(push 전용).
Apple 로그인은 다음 키가 **있는 entitlements로 빌드**되어야 한다(별도 파일 추가 or push 파일에 병합):
```xml
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
```
`project.yml`의 App 타겟 `CODE_SIGN_ENTITLEMENTS`가 그 파일을 가리키게 하고 `xcodegen generate`.

---

## 3. 클라이언트 구현 (SDK 없이, REST 직결)

### 3-1. 토큰 받기 → GoTrue 교환 (정확한 REST 형태)
1. `ASAuthorizationAppleIDProvider`로 로그인 → `ASAuthorizationAppleIDCredential.identityToken`(JWT, `Data`) 획득.
   - `requestedScopes = [.fullName, .email]` (email/이름은 **최초 1회만** 옴 → 받으면 닉네임 기본값으로 보관).
   - replay/CSRF 방지로 `nonce`를 생성해 request에 넣고, 같은 nonce를 교환 시 전달.
2. GoTrue로 교환:
```
POST {SUPABASE_URL}/auth/v1/token?grant_type=id_token
apikey: {SUPABASE_ANON_KEY}
Content-Type: application/json

{
  "provider": "apple",
  "id_token": "<identityToken을 UTF-8 문자열로>",
  "nonce": "<raw nonce (요청에 넣은 평문)>"
}
```
응답(요지):
```json
{
  "access_token": "eyJ...",   // 짧은 수명 JWT (sub = auth user id = uuid)
  "refresh_token": "v1.M...", // 장기 보관용
  "expires_in": 3600,
  "token_type": "bearer",
  "user": { "id": "uuid", "email": "...", "app_metadata": {...} }
}
```
3. 갱신:
```
POST {SUPABASE_URL}/auth/v1/token?grant_type=refresh_token
apikey: {ANON}
{ "refresh_token": "<저장된 refresh_token>" }
```
4. 로그아웃:
```
POST {SUPABASE_URL}/auth/v1/logout
apikey: {ANON}
Authorization: Bearer {access_token}
```

### 3-2. 세션 저장 — Keychain
UserDefaults가 아니라 **Keychain**에 저장(`access_token`/`refresh_token`/만료시각/user id).
- 새 파일 제안: `App/Sources/Networking/AuthSession.swift`
  - `static var current: Session?` (Keychain 로드/캐시)
  - `func appleSignIn(idToken:nonce:) async -> Bool` (3-1 교환)
  - `func validAccessToken() async -> String?` (만료 임박 시 refresh 후 반환)
  - `func signOut()`
- `bl_device_id`(UserDefaults)는 **그대로 유지**한다(전환기 secondary key + 비로그인 폴백).

### 3-3. `SupabaseConfig` / `request()` 변경 형태
`request()`는 한 군데에서만 헤더를 만든다. **로그인 세션이 있으면 access_token, 없으면 anon key**를
Bearer로 붙이도록 바꾼다(`apikey`는 항상 anon — PostgREST 진입에 필요).

현재:
```swift
req.setValue(key, forHTTPHeaderField: "apikey")
req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
req.setValue(SupabaseConfig.deviceID, forHTTPHeaderField: "x-device-id")
```
변경(개념):
```swift
// request()는 async가 되거나, 호출부에서 토큰을 받아 주입
let bearer = await AuthSession.current?.validAccessToken() ?? key  // 없으면 anon 폴백
req.setValue(key, forHTTPHeaderField: "apikey")                    // apikey는 항상 anon
req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
req.setValue(SupabaseConfig.deviceID, forHTTPHeaderField: "x-device-id")
```
주의:
- `request()`가 동기 함수라 `validAccessToken()`을 부르려면 **async로 승격**하거나, 호출 직전에
  토큰을 한 번 받아 파라미터로 넘기는 헬퍼(`requestAuthed(...) async`)를 추가한다.
  `fetchPosts`/`fetchMeetups`처럼 `request()`를 안 쓰고 직접 `URLRequest`를 만드는 곳(현재 read 경로)도
  같은 규칙으로 Bearer를 통일한다.
- `author`/`host`/`creator`/`device_id`에 넣는 값은 전환기엔 **여전히 `deviceID`**를 보낸다.
  RLS가 owner를 `auth.uid()`로 강제하기 시작하면(5장 transition 종료) 작성 컬럼을
  `auth.uid()`(=세션 user id)로 바꾸고 `device_id`는 보조로만 남긴다.

### 3-4. 트레이드오프 & 권장
| 항목 | REST 직결(권장) | supabase-swift SDK |
| --- | --- | --- |
| 의존성 | 0 (현 패턴 그대로) | SPM 패키지 추가, 빌드시간↑ |
| 세션 갱신 | 직접 구현(refresh/Keychain) | 자동 |
| Realtime/Storage 향후 | 직접(현재 Realtime 미사용) | 내장 편의 |
| 포지셔닝 | "Apple 프레임워크만" 유지 | 서드파티 고지 추가 필요 |

**권장: REST 직결.** 추가 엔드포인트가 사실상 토큰 교환/갱신 2개뿐이고 기존 PostgREST 패턴과 동일하다.
나중에 Storage(사진 백업)·Realtime(채팅)을 본격 쓰게 되면 그때 SDK 도입을 재평가.

---

## 4. 익명 → 계정 업그레이드 / 마이그레이션

핵심: **로그인 전에 만든 콘텐츠를 잃지 않는다.** 키는 `bl_device_id`(현재) → `auth.uid()`(신규)로 옮긴다.

### 4-1. 전략 — 로그인 시 1회 device_id 클레임
사용자가 처음 Apple 로그인에 성공하면, 그 세션(access_token, `sub=auth user id`)으로
**내 기기 UUID가 박힌 행을 내 user id로 귀속**시킨다.

- 권장: Supabase **RPC(서버 함수)** `claim_device(p_device uuid)` 하나로 처리(여러 테이블 UPDATE를 트랜잭션으로).
  앱은 로그인 직후:
  ```
  POST {SUPABASE_URL}/rest/v1/rpc/claim_device
  apikey: {ANON}
  Authorization: Bearer {access_token}
  { "p_device": "<bl_device_id>" }
  ```
- 서버 함수(개념, `supabase/schema_auth.sql`에 둘 것 — 이 문서는 생성하지 않음):
  ```sql
  create or replace function public.claim_device(p_device text)
  returns void language plpgsql security definer set search_path = public as $$
  begin
    -- 소유자 컬럼이 text(UUID 문자열)인 기존 테이블을 auth.uid()로 귀속
    update crew_post          set author  = auth.uid()::text where author  = p_device;
    update crew_post_reply    set author  = auth.uid()::text where author  = p_device;
    update crew_meetup        set host    = auth.uid()::text where host    = p_device;
    update crew_group         set creator = auth.uid()::text where creator = p_device;
    -- 멤버십/좋아요/참가/메시지: device_id 컬럼을 보조로 유지하되 owner 표식 추가는 5장 참고
    update crew_post_like     set device_id = auth.uid()::text where device_id = p_device;
    update crew_meetup_join   set device_id = auth.uid()::text where device_id = p_device;
    update crew_group_member  set device_id = auth.uid()::text where device_id = p_device;
    update crew_meetup_message set device_id = auth.uid()::text where device_id = p_device;
  end $$;
  ```
  `security definer`라 RLS를 우회해 일괄 업데이트 가능(함수 안에서 `auth.uid()`로 본인만 귀속하므로 안전).
  - 대안(함수 없이): 앱이 각 테이블에 `PATCH .../crew_post?author=eq.<device>` UPDATE를 보내는 방법도 있으나,
    전환기 RLS가 `using(true)`인 동안만 가능하고 트랜잭션 보장이 없어 **RPC를 권장**.

### 4-2. device_id를 보조 키로 유지(전환기)
- 같은 사람이 **여러 기기**를 쓰면, 각 기기가 로그인할 때 자기 `bl_device_id`로 `claim_device`를 호출 →
  모든 기기 콘텐츠가 같은 `auth.uid()`로 모인다.
- `device_id` 컬럼은 **삭제하지 않는다.** (a) 비로그인 사용자 폴백, (b) 마이그레이션 추적,
  (c) 좋아요/참가 dedup 유니크 키(`on_conflict=post_id,device_id` 등 현재 코드가 의존).
  전환기엔 owner 식별을 `device_id == auth.uid()::text`가 되도록 위 함수가 값을 맞춰준다.

### 4-3. 로그인 전 만든 콘텐츠
- **유지된다.** claim 전까지는 `author=<device uuid>`로 남아 표시/동작하고(절대 원칙 "데이터 인질극 금지"와 일치),
  로그인 시 자동 귀속된다.
- **로그인 안 한 사용자**도 계속 쓸 수 있어야 한다(크루는 익명 참여가 기본값). 로그인은 "본인 글 보호 + 멀티기기"를
  원하는 사람의 **옵션**으로 둔다. RLS는 5장처럼 `anon` insert를 막지 않도록 transition 정책을 둔다.

---

## 5. RLS 강화 (전환기 호환)

현재(`supabase/schema_crew.sql` 91~104줄)는 8개 테이블 전부:
```sql
create policy <t>_all on public.<t> for all to anon, authenticated using (true) with check (true);
```
이를 **읽기 개방 / 쓰기는 본인(또는 전환기 device 링크)만**으로 교체. 아래는 적용 대상 SQL(별도 파일
`supabase/schema_crew_rls.sql` 권장, 이 문서는 생성하지 않음). owner 컬럼은 현재 `text`이므로
`auth.uid()::text`로 비교한다.

> 핵심 아이디어: **읽기**는 모두 허용(동네 커뮤니티). **insert**는 본인 표식이 박혀야 함.
> **update/delete**는 본인 행만. 전환기엔 `device_id == auth.uid()::text`(claim 이후) 또는
> 익명 기기 owner도 허용하는 보조 조건을 둔다.

### 5-1. 글/모임/그룹 (owner 컬럼이 author/host/creator)
```sql
-- crew_post (owner = author)
drop policy if exists crew_post_all on public.crew_post;
create policy crew_post_read on public.crew_post for select to anon, authenticated using (true);
create policy crew_post_ins  on public.crew_post for insert to anon, authenticated
  with check ( author = coalesce(auth.uid()::text, author) );   -- 로그인 시 본인 표식 강제, 익명은 device uuid 허용
create policy crew_post_upd  on public.crew_post for update to authenticated
  using ( author = auth.uid()::text ) with check ( author = auth.uid()::text );
create policy crew_post_del  on public.crew_post for delete to authenticated
  using ( author = auth.uid()::text );

-- crew_post_reply (owner = author)  — 위와 동일 패턴
drop policy if exists crew_post_reply_all on public.crew_post_reply;
create policy crew_post_reply_read on public.crew_post_reply for select to anon, authenticated using (true);
create policy crew_post_reply_ins  on public.crew_post_reply for insert to anon, authenticated
  with check ( author = coalesce(auth.uid()::text, author) );
create policy crew_post_reply_upd  on public.crew_post_reply for update to authenticated
  using ( author = auth.uid()::text ) with check ( author = auth.uid()::text );
create policy crew_post_reply_del  on public.crew_post_reply for delete to authenticated
  using ( author = auth.uid()::text );

-- crew_meetup (owner = host)
drop policy if exists crew_meetup_all on public.crew_meetup;
create policy crew_meetup_read on public.crew_meetup for select to anon, authenticated using (true);
create policy crew_meetup_ins  on public.crew_meetup for insert to anon, authenticated
  with check ( host = coalesce(auth.uid()::text, host) );
create policy crew_meetup_upd  on public.crew_meetup for update to authenticated
  using ( host = auth.uid()::text ) with check ( host = auth.uid()::text );
create policy crew_meetup_del  on public.crew_meetup for delete to authenticated
  using ( host = auth.uid()::text );

-- crew_group (owner = creator)
drop policy if exists crew_group_all on public.crew_group;
create policy crew_group_read on public.crew_group for select to anon, authenticated using (true);
create policy crew_group_ins  on public.crew_group for insert to anon, authenticated
  with check ( creator = coalesce(auth.uid()::text, creator) );
create policy crew_group_upd  on public.crew_group for update to authenticated
  using ( creator = auth.uid()::text ) with check ( creator = auth.uid()::text );
create policy crew_group_del  on public.crew_group for delete to authenticated
  using ( creator = auth.uid()::text );
```

### 5-2. 멤버십/좋아요/참가/메시지 (owner = device_id)
이 4개 테이블의 행은 "나의 가입/좋아요/참가/메시지"이므로 owner = `device_id`.
```sql
-- crew_post_like
drop policy if exists crew_post_like_all on public.crew_post_like;
create policy crew_post_like_read on public.crew_post_like for select to anon, authenticated using (true);
create policy crew_post_like_ins  on public.crew_post_like for insert to anon, authenticated
  with check ( device_id = coalesce(auth.uid()::text, device_id) );
create policy crew_post_like_del  on public.crew_post_like for delete to anon, authenticated
  using ( device_id = coalesce(auth.uid()::text, device_id) );  -- 본인 좋아요만 취소

-- crew_meetup_join (동일 패턴, device_id)
drop policy if exists crew_meetup_join_all on public.crew_meetup_join;
create policy crew_meetup_join_read on public.crew_meetup_join for select to anon, authenticated using (true);
create policy crew_meetup_join_ins  on public.crew_meetup_join for insert to anon, authenticated
  with check ( device_id = coalesce(auth.uid()::text, device_id) );
create policy crew_meetup_join_del  on public.crew_meetup_join for delete to anon, authenticated
  using ( device_id = coalesce(auth.uid()::text, device_id) );

-- crew_group_member (동일 패턴, device_id)
drop policy if exists crew_group_member_all on public.crew_group_member;
create policy crew_group_member_read on public.crew_group_member for select to anon, authenticated using (true);
create policy crew_group_member_ins  on public.crew_group_member for insert to anon, authenticated
  with check ( device_id = coalesce(auth.uid()::text, device_id) );
create policy crew_group_member_del  on public.crew_group_member for delete to anon, authenticated
  using ( device_id = coalesce(auth.uid()::text, device_id) );

-- crew_meetup_message (owner = device_id; 메시지는 수정 없음, 본인만 삭제)
drop policy if exists crew_meetup_message_all on public.crew_meetup_message;
create policy crew_meetup_message_read on public.crew_meetup_message for select to anon, authenticated using (true);
create policy crew_meetup_message_ins  on public.crew_meetup_message for insert to anon, authenticated
  with check ( device_id = coalesce(auth.uid()::text, device_id) );
create policy crew_meetup_message_del  on public.crew_meetup_message for delete to authenticated
  using ( device_id = auth.uid()::text );
```

### 5-3. 전환기 호환 메모
- `coalesce(auth.uid()::text, x)` 패턴은 **익명(anon, `auth.uid()` = NULL)이면 자기 표식(device uuid)을 그대로
  쓰게 허용**하고, 로그인 사용자는 owner를 `auth.uid()`로 강제한다 → 현재 앱 코드(여전히 `deviceID`를 보냄)와
  **호환**. claim 이후엔 그 device 행들의 owner 값이 `auth.uid()::text`로 바뀌어 update/delete 정책과 맞물린다.
- **주의(전환기 한계)**: insert에 `coalesce` 폴백을 두면 익명 사용자가 임의 device uuid를 박을 수 있다(완전 잠금 아님).
  진짜 잠금은 (a) 로그인 의무화 후 `coalesce` 제거, (b) `x-device-id` 헤더를 신뢰 서명값으로 바꾸기 중 하나.
  MVP→전환기엔 "본인 글 update/delete 보호"가 1차 목표이므로 위 정책으로 충분, insert 완전 잠금은 로그인 의무화 단계에서.
- 적용 순서: claim_device(4장)로 기존 데이터 owner를 먼저 정리한 뒤 RLS 교체. 안 그러면 옛 행을 본인이 못 고치게 됨.

---

## 6. 온보딩/설정 연결 (위치만, 구현 X)

- **온보딩**: `App/Sources/Features/Onboarding/OnboardingView.swift` 170~179줄에 이미
  **"이미 계정이 있어요"** 버튼이 있다. 현재는 `onComplete()`만 호출 → 여기를 Apple 로그인 시트
  (`SignInWithAppleButton` 또는 `ASAuthorizationController`)로 연결하면 된다. `.accessibilityLabel`도 이미 있음.
- **설정/내정보**: `App/Sources/Features/Settings/SettingsScreen.swift`, `App/Sources/Features/Profile/ProfileScreen.swift`.
  로그인 상태/계정 섹션(로그인 안내 또는 "로그아웃·계정 삭제")을 여기에 surface.
  - Apple 가이드라인상 Sign in with Apple을 쓰면 **계정 삭제 경로** 제공 의무 → 설정에 "계정 삭제"도 함께 둘 것.
- 신규 진입 버튼(첫 화면 CTA 위쪽 등)은 SPEC 4.7(인증: Supabase Auth + Apple Sign-in, line 529)과 일치.
- **이 문서에서는 와이어링만 식별하고 구현하지 않는다.**

---

## 7. 단계별 롤아웃 체크리스트

피처 플래그(원격 구성/`APIConfig` 기반 토글) 뒤에서 점진 출시. **RLS 잠금은 데이터 정리 후**가 철칙.

1. **[플래그 OFF로 선반영, 심사 불필요]**
   - Supabase: Apple provider 활성(2장). 기존 anon 동작 영향 없음.
   - DB: `claim_device` RPC 추가(4장). 호출 전엔 무영향.
2. **[앱 빌드, 심사 필요 — entitlement 변경]**
   - entitlements에 `com.apple.developer.applesignin` 추가 + `project.yml` 연결 + `xcodegen generate`(6장/2-3).
   - `AuthSession.swift`(Keychain·토큰교환) 추가, `request()`를 token-aware로(3-3). 로그인 UI는 **플래그 뒤**.
   - 비로그인 경로는 그대로 동작해야 함(회귀 금지) — 플래그 OFF면 anon key 사용.
3. **[플래그 ON 일부 동네/베타]**
   - 온보딩/설정에 로그인 노출(6장). 로그인 → `claim_device` 호출 → 본인 콘텐츠 귀속 확인.
4. **[RLS 1차 교체 — read 개방 / update·delete 본인만]**
   - 먼저 `claim_device`로 기존 데이터 owner 정리됐는지 확인 후, 5장 정책 적용. insert는 `coalesce` 폴백 유지(익명 허용).
5. **[선택: 로그인 의무화 단계]**
   - 글쓰기/모임개설을 로그인 필수로 전환할지 결정 → 그때 insert에서 `coalesce` 폴백 제거(완전 잠금).

### 심사 영향 요약
- **심사 필요**: entitlement 추가 빌드, 로그인 UI가 보이는 빌드, 계정 삭제 경로.
- **심사 불필요**: Supabase provider/RPC/RLS 같은 서버 측 변경(앱 바이너리 무변경).

---

## 8. 창업자 결정 사항 (open)

1. **로그인 의무화 vs 영구 옵션** — 크루는 익명 참여가 기본. 로그인을 끝까지 옵션으로 둘지,
   특정 행위(글쓰기·모임개설)만 로그인 필수로 할지. (현재 권장: 영구 옵션 + 본인 글 보호)
2. **Service ID/Key 생성 시점** — 안드로이드(KMP/Flutter)·웹 계획이 가까우면 지금 만들고, 아니면 네이티브 전용으로 미룸.
3. **insert 완전 잠금 시점** — `coalesce` 폴백을 언제 제거할지(익명 위조 insert 차단 vs 익명 사용성).
4. **닉네임 소스** — Apple은 이름을 최초 1회만 줌. 받은 이름을 `author_name` 기본값으로 쓸지, 항상 직접 입력받을지.
5. **계정 삭제 정책** — Apple 가이드라인 의무. 콘텐츠는 익명화(소유 해제) vs 삭제? (절대 원칙 "무료 데이터 영구 보존"과
   조율: 본인 식별만 끊고 콘텐츠는 익명 유지가 일관적).
6. **email scope 수집 여부** — 받지 않아도 로그인은 됨. 알림/복구용으로 받을지(개인정보 최소수집 원칙과 조율).

---

## 부록 — Secrets.plist 변경 없음
`SUPABASE_URL` / `SUPABASE_ANON_KEY`(`App/Resources/Secrets.plist`, `docs/SUPABASE_SETUP.md`)를 **그대로** 사용한다.
Apple 로그인용 추가 키는 **앱에 불필요**(검증은 Supabase가 함). Apple .p8/Key ID/Service ID는 **Supabase Dashboard에만** 들어간다.
