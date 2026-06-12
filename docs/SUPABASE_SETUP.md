# Supabase 백엔드 셋업 (크루 MVP)

크루(동네 모임)의 실제 동작에 필요한 서버. 우선 **동네별 대기 신청 → 이웃 모이면 자동 오픈**부터.

## 1. 프로젝트 생성 (한 번만)
1. https://supabase.com 가입 → **New project** (Free 플랜이면 충분)
2. 리전: **Northeast Asia (Seoul)** 권장
3. 생성 후 **Project Settings → API** 에서 두 값 복사:
   - **Project URL** (예: `https://abcd.supabase.co`)
   - **anon public** API key

## 2. 스키마 적용
- 대시보드 **SQL Editor** → `supabase/schema.sql` 내용 붙여넣고 **Run**.
- `crew_waitlist` 테이블 + 카운트 RPC + RLS가 생성됩니다.

## 3. 앱에 키 넣기
`App/Resources/Secrets.plist`(깃 제외)에 추가:
```xml
<key>SUPABASE_URL</key>      <string>https://abcd.supabase.co</string>
<key>SUPABASE_ANON_KEY</key> <string>eyJ...(anon key)...</string>
```
→ 키가 있으면 크루 대기 신청이 **실제 서버**로, 없으면 자동으로 목업 동작(B4 폴백 정책).

## 4. 동작
- 오픈 전 화면에서 "알림 받기/대기 신청" → 내 동네(`hood`) + 익명 기기ID가 `crew_waitlist`에 1행.
- 동네별 신청 수를 RPC로 읽어 **준비도(현재/목표)** 표시. 목표(기본 30명) 도달 시 크루 오픈 후보.
- 아동·개인정보는 서버에 저장하지 않음(동네명 + 익명 기기 UUID만).

## 다음 단계(로드맵)
- 크루 그룹·모임·게시판 테이블/RLS (오픈된 동네부터)
- 인증 강화: 익명 → Apple 로그인(선택)
- 마켓(중고거래) 서버 — [docs/BACKEND_TODO.md](BACKEND_TODO.md)
