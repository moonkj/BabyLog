# 계정 삭제(Edge Function) 배포 가이드 — App Store 심사 필수

Sign in with Apple을 제공하는 앱은 **앱 내 계정 삭제 경로**를 반드시 제공해야 한다(Apple App Store 심사 가이드라인 5.1.1(v)). 미제공 시 **리젝**된다.

상태:
- ✅ 함수 코드: `supabase/functions/delete-account/index.ts` (작성 완료)
- ✅ 앱 연결: 설정 → 계정 → **계정 삭제** 버튼 → `AuthStore.deleteAccount()` → `POST /functions/v1/delete-account`
- ⏳ **남은 일: 함수 배포(아래)** — 배포 전엔 버튼이 "처리하지 못했어요"로 실패한다.

> 동작: 호출자(로그인 사용자)의 JWT로 본인 확인 → `service_role`로 `auth.users`에서 본인 삭제.
> **작성한 콘텐츠(글·매물·댓글)는 삭제하지 않는다** — 소유 UUID만 고아화(익명)되어 "무료 데이터 영구 보존" 원칙과 일치. 본인 식별만 끊긴다.

---

## 배포 (둘 중 하나)

### 방법 A — Supabase CLI (권장)
```bash
# 1) CLI 설치(최초 1회): brew install supabase/tap/supabase
# 2) 로그인(브라우저 인증 — 폐기한 sbp_ 토큰과 무관, CLI 자체 세션)
supabase login

# 3) 프로젝트 연결(최초 1회)
cd /Users/kjmoon/BabyLog
supabase link --project-ref rqlfyumzmpmhupjtroid

# 4) 배포
supabase functions deploy delete-account
```
- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` 는 **플랫폼이 자동 주입**한다 → 따로 시크릿 설정 불필요.
- 기본 배포(JWT 검증 on)로 충분하다. 앱이 **사용자 access token**을 Authorization 헤더로 보내므로 게이트웨이 검증을 통과한다. (`--no-verify-jwt` 쓰지 말 것 — 켜둬야 안전.)

### 방법 B — 대시보드
Supabase Dashboard → **Edge Functions** → **Deploy a new function** → 이름 `delete-account` → `supabase/functions/delete-account/index.ts` 내용 붙여넣기 → Deploy.

---

## 배포 후 검증
1. 앱 → **설정 → 계정** (로그인 상태)
2. **계정 삭제** → 확인
3. 기대: "계정을 삭제했어요…" 안내 + 로그아웃됨. 같은 Apple ID로 다시 로그인하면 **새 user**로 생성된다(이전 익명 콘텐츠는 익명으로 남음).

연기 테스트(선택, 로그인 토큰 필요):
```
POST {SUPABASE_URL}/functions/v1/delete-account
apikey: {ANON}
Authorization: Bearer {사용자 access_token}
→ 200 {"deleted": true, "user": "<uuid>"}
```

---

## 참고 / 주의
- 이 함수는 `service_role` 키로 동작한다(자동 주입). 이 키는 **절대 클라이언트/깃에 넣지 않는다** — Edge Function 런타임에만 존재.
- `auth.users` 삭제 시 해당 user의 `crew_*`/`market_*` 행은 남는다(owner 컬럼이 옛 uid 문자열로 고아화). 의도된 동작(영구 보존 + 식별 해제). 완전 삭제 정책이 필요하면 함수에 콘텐츠 삭제/익명화 UPDATE를 추가.
- 출시 빌드 전 함께: APNS_HOST→`api.push.apple.com`, `aps-environment`→`production`, 마켓 30일 만료 pg_cron.
