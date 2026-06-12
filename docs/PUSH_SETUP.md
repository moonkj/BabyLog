# 실시간 크루 오픈 푸시 (APNs) 셋업

동네가 목표 인원에 도달하는 순간, 그 동네 모든 기기에 **앱이 꺼져 있어도** 푸시 발송.

## ⚠️ 전제: 유료 Apple Developer Program ($99/년)
원격 푸시(APNs)는 **유료 멤버십이 필수**입니다. 무료/개인 팀은 Push 역량·APNs 키를 만들 수 없어 실시간 푸시가 불가합니다.
- 무료 계정이면: 지금 동작하는 **"앱 열 때 로컬 알림"**으로 충분(이미 적용됨). 유료 전환 후 아래 진행.

## 1. APNs 인증 키 생성 (Apple Developer, 유료)
1. developer.apple.com → Certificates, Identifiers & Profiles → **Keys** → **+**
2. 이름 입력 + **Apple Push Notifications service (APNs)** 체크 → Continue → Register
3. **.p8 파일 다운로드**(한 번만!) + **Key ID**(10자) 메모. **Team ID** = `QN975MTM7H`
4. **Identifiers → `com.babylog.app`** → **Push Notifications** 체크 → Save

## 2. 앱 Push 역량 켜기
- `App/Resources/BabyLog.entitlements` 에 `aps-environment` 있음(생성됨).
- `project.yml`의 App 타겟 settings에서 주석 해제:
  ```yaml
  CODE_SIGN_ENTITLEMENTS: App/Resources/BabyLog.entitlements
  ```
  → `xcodegen generate` 후 빌드. (유료 계정 + App ID Push 활성 상태라야 프로비저닝 성공)

## 3. Supabase
1. SQL Editor에 `supabase/schema_push.sql` 실행(crew_push_token / crew_hood_status).
2. **Edge Functions → notify-crew-open** 배포:
   - `supabase functions deploy notify-crew-open` (Supabase CLI) 또는 대시보드에서 함수 생성 후 `supabase/functions/notify-crew-open/index.ts` 붙여넣기.
   - **Secrets** 설정: `APNS_KEY`(.p8 내용 전체), `APNS_KEY_ID`, `APNS_TEAM_ID=QN975MTM7H`, `APNS_TOPIC=com.babylog.app`, `APNS_HOST=api.sandbox.push.apple.com`(개발) 또는 `api.push.apple.com`(배포)
3. **Database → Webhooks → Create**:
   - Table: `crew_waitlist`, Events: **Insert**
   - Type: **Supabase Edge Functions** → `notify-crew-open`
   → 신청이 들어올 때마다 함수가 동네 인원을 확인하고, 목표 도달 & 미오픈이면 푸시 발송.

## 4. 동작 확인
- 같은 동네에서 목표(30명) 도달 → 그 동네 토큰 등록 기기 전체에 푸시.
- 개발 빌드는 `APNS_HOST=...sandbox...`, TestFlight/배포는 `...push.apple.com`.

## 임계값
- `CrewBackend.openThreshold`(앱) / Edge Function `THRESHOLD`(서버) 둘 다 30. 바꾸면 양쪽 일치시킬 것.
