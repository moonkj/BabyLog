# 가족과 사진 공유 (클라우드 가족 피드)

> 상태: **v1 라이브(2026-06-15)**. 앱·웹·서버 end-to-end 구현·배포 완료. 아래 "구현 현황(v1)"이 실제 동작이며, 그 아래 11~12절은 초기 설계 맥락(일부 변경됨)이다.
> 결정 맥락은 메모리 `pro-family-feed-infra`·`family-photo-sharing`.

---

## 구현 현황 (v1, 2026-06-15) — 실제 동작

**모델 변경 요약(초기 설계 대비):**
- 가족 사진 공유는 v1에서 **무료에도 개방**(부부 2명). 즉 무료 2인 가족 피드도 R2를 쓴다 → 절대원칙 "무료는 사진 서버 비전송"을 **가족 공유 범위에서 의식적으로 완화**(2026-06 결정, CLAUDE.md 갱신). **아동 기록 원본(성장·일기·접종·가계부)은 여전히 서버에 안 올린다.**
- **영상도 v1에서 무료 포함**(사진과 동일 경로). 비용 통제: **영상 개수 상한 등급별 — 무료 100 / Pro 300**(주인 `is_pro` 기준, 서버 `media-upload-url`이 강제, 초과 시 `video_cap`+`cap` 403), 클라이언트 **720p·60초** 압축 + 포스터 프레임. 앱 가족 피드 상단에 **"영상 N/cap" 카운터** 노출(상한 근접 시 빨강). 비주인 멤버용 캡 조회는 RPC `bl_video_cap`(SECURITY DEFINER). 시청은 R2(egress 무료)라 무제한 반복 시청해도 추가 비용 0 — 저장량만 상한으로 묶음.
- 옛 iCloud 공유앨범 방식(`FamilyShareScreen`)은 **제거**(코드 삭제). 진입점은 가족 피드 하나로 일원화.

**등급 (서버 강제):**
- **무료** = 주인 + 1명(배우자) = **2명**. 플랫폼 무관(아이폰/안드로이드).
- **Pro** = 조부모·친척·크로스플랫폼까지 **최대 8명**. 월 **₩990** / 연 **₩9,900**(2개월 무료).
- 인원·등급은 **`bl_approve_member`**(승인 시 무료 2/Pro 8 검사), 열람 권한은 **`bl_is_family_member`**(주인+무료 파트너 1명은 항상, 그 외는 주인 `is_pro`일 때만)에서 강제.

**합류/보안 흐름:**
- 부모가 "조부모님 및 가족 초대하기" → 초대코드 링크 + **숫자 비밀번호(4~10자리)**. 링크는 메신저, 비번은 따로(전화 등).
- 받은 사람: 배우자(아이폰)는 앱 "가족 참여하기"(코드+비번), 조부모/안드로이드는 **웹**(`https://babylog-family.pages.dev/family/?invite=CODE`)에서 **익명 로그인 + 성함 + 비번**으로 합류. 익명 세션 = 기기 바인딩(폰 바꾸면 재신청).
- **승인제**: 합류는 곧바로 "승인 대기"(아무것도 못 봄) → 주인이 앱 "가족 관리"에서 승인해야 열람. 합류 시 **주인에게 APNs 푸시**(`notify-family-join`).
- **구독 만료**: 부부(2명)는 유지, 조부모·친척은 차단(웹에 "지금은 볼 수 없어요" 안내, 재구독 시 자동 복구). 기존 데이터는 보존(인질극 금지) — 차단은 '보기 권한'만.

**관련 서버 객체:** `schema_family_feed.sql`(테이블·RLS), `schema_family_invite.sql`(`bl_claim_invite` 3-arg·`bl_set_family_pass`·`bl_set_my_name`·멤버 삭제 정책), `schema_family_approval.sql`(`approved` 컬럼·`bl_is_family_member` 구독 게이팅·`bl_approve_member`). Edge: `media-upload-url`(R2 presign, is_pro 게이트 제거 — 멤버십만 + 영상 상한 `video_cap` 무료100/Pro300), `media-delete`, `notify-family-join`(합류 푸시). SQL: `schema_video_cap.sql`(`bl_video_cap` RPC — 카운터 분모). 웹: `web/family/index.html`(Cloudflare Pages), 배포본 `web-dist/`(gitignore).

**v2 (미구현):** 부부 **앱 전체 데이터(성장·일기·접종·가계부) 공유** = CloudKit **CKShare**(개인 iCloud, 우리 서버 X). 2번째 애플ID 필요. B1(개인 iCloud 백업·`BL_CLOUDKIT`·`iCloud.com.vibelab.babylog`)은 라이브.

---

## 1. 한 줄 요약

큰 전제는 **사진(+영상) 업로드 모델**.
- **무료** = 나 혼자 보는 개인 저널 (미디어 = 로컬/iCloud, 우리 서버 미사용). 소셜 없음(즐겨찾기 ⭐만).
- **Pro "클라우드 가족 보관함"** = 우리 서버에 올려 **가족 모두가 보고 하트·댓글**(양방향) + **풀화질 영구 백업**. 업로드 1회가 공유와 백업을 동시 해결. 영상 포함(안드로이드 조부모도 시청).

## 2. 절대 지킬 원칙 (CLAUDE.md)

- 아동 안전: 가족 피드는 **초대된 가족만** 접근(공개 아님). 미디어 URL은 추측 불가 키 + 가족 토큰 게이트.
- 데이터 비매각 / 무광고. 무료 데이터 영구 보존(무료는 서버에 없음 — 로컬/iCloud).
- "사진은 서버에 안 올림"은 **무료** 약속. **Pro는 명시적 서버 백업 동의** 위에서만 업로드(원칙과 일치 — "서버 백업은 Pro 혜택").
- ~~영상은 Pro 전용~~ → **v1에서 영상도 무료 포함**(위 "구현 현황" 참조). 개수 상한 무료 100 / Pro 300·720p·60초로 비용 통제.

## 3. 아키텍처 개요

```
[iOS 앱(부모/조부모)]                         [안드로이드 조부모]
   │  Apple 로그인(AuthStore)                     │  웹 뷰어(브라우저)
   │                                              │  가족 토큰 링크
   ▼                                              ▼
[Supabase]  Postgres(피드·하트·댓글 텍스트) + Auth + Edge Functions
   │  - R2 presigned URL 발급(Edge)
   │  - 구독 영수증 검증 → is_pro
   ▼
[Cloudflare R2 + CDN]  사진/영상 바이트 (egress 무료)
```

핵심 분리: **무거운 바이트는 R2(트래픽 무료), 텍스트·관계·상호작용은 Supabase.** 미디어는 Supabase Storage를 절대 통과시키지 않는다(egress 과금 폭탄 방지).

## 4. 데이터 모델 (Supabase Postgres) — `supabase/schema_family_feed.sql`

⚠️ **공유 프로젝트(rqlfyumzmpmhupjtroid, cafeVibe·noisespot 공용)라 모든 테이블·함수에 `bl_` 접두사**로 네임스페이스(충돌 방지). 아래 표의 이름은 실제로 `bl_family`, `bl_family_member`, `bl_feed_post`, `bl_post_media`, `bl_reaction`, `bl_comment`, `bl_profile`. 출시(결제 켜기) 전 BabyLog 전용 프로젝트로 분리 권장.

| 테이블(실제명 bl_*) | 핵심 컬럼 | 비고 |
|---|---|---|
| `family` | id, owner_uid, name, created_at | Pro 부모가 생성 |
| `family_member` | family_id, uid(nullable), invite_code, role(parent/grandparent), display_name, joined_at | 조부모 초대 |
| `feed_post` | id, family_id, author_uid, child_label, caption, milestone, taken_at, created_at | child_label=비식별 표시명 |
| `post_media` | id, post_id, kind(photo/video), r2_key, thumb_key, w, h, duration_s, bytes | 바이트는 R2, 여기엔 키만 |
| `reaction` | post_id, uid, kind(heart), created_at · unique(post_id,uid,kind) | 양방향 하트 |
| `comment` | id, post_id, uid, author_name, text, created_at | 양방향 댓글 |

RLS: 모든 테이블 `family_member`에 속한 uid만 read/write. owner는 family 관리. (기존 `schema_crew_rls.sql` 패턴 재사용.)

## 5. 미디어 파이프라인 (R2)

- **업로드(직결)**: 앱 → Edge Function `media-upload-url`(가족 멤버 + Pro 검증) → R2 **presigned PUT URL** 발급 → 앱이 R2로 직접 PUT. 우리 컴퓨트·Supatrans 거치지 않음.
- **압축(클라이언트)**:
  - 사진: 원본 풀화질 1장 + 썸네일(~30KB, 긴변 320px). `PhotoStore`/`ImageRenderer` 재사용.
  - 영상: **AVAssetExportSession 720p + 길이 캡 1~2분**(초과분 거부/안내). 포스터 프레임 썸네일.
- **서빙**: Cloudflare CDN 경유. 가족 전용이므로 (a) 추측 불가 키(UUID) + (b) 짧은 수명 signed GET URL 또는 가족 토큰 검증. CDN 캐시로 재시청 폭주에도 R2 read·egress 0 수렴.
- **키 스킴**: `r2://{family_id}/{post_id}/{media_id}.{ext}`, 썸네일 `..._thumb.jpg`.

## 6. 비용 가드 (저가 구독·마진 유지)

- 미디어 = **R2 + Cloudflare CDN(egress 무료)**. ⚠️ Supabase Storage/S3로 영상 서빙 금지.
- 720p·길이캡·월 업로드 합리적 상한.
- 무료 사용자에겐 서버 미디어 서빙 안 함.
- 추정: 가정당 월 원가 ~$0.1~0.15(저장+DB), 영상 재시청 무관(R2 egress 0). 자세한 계산은 메모리 `family-photo-sharing`.

## 7. 구독 (StoreKit 2)

- 상품: `com.vibelab.babylog.pro.monthly`(₩990), `...pro.yearly`(₩9,900). App Store Connect 등록 필요.
- 클라이언트: `Transaction.currentEntitlements`로 Pro 활성 확인 → `isPro` 게이트(가족 생성·업로드 노출).
- 서버: Edge Function `verify-subscription`이 App Store Server API(JWS)로 검증 → `profile.is_pro` 갱신. **업로드/가족 생성 Edge에서 is_pro 재확인**(클라이언트 우회 방지).
- 정직 결제(CLAUDE.md): 자동결제 사전 고지, 해지 쉽고 존중 톤. 다크패턴 금지.

## 8. 안드로이드 조부모

- 경량 **웹 뷰어**(Cloudflare Pages 정적): 가족 초대 링크의 토큰으로 피드 read + 하트·댓글 write(가족 게스트 토큰). 미디어는 R2/CDN. Apple ID 불필요.
- v1은 read+react 우선, 업로드는 iOS 가족만(후속에서 웹 업로드 검토).

## 9. 무료 ↔ Pro 경계

- 무료: 가족 피드 부부 2명까지(R2). 옛 iCloud 공유앨범(FamilyShareScreen)은 제거됨.
- Pro 전환 시: 기존 로컬 사진을 가족 피드로 **선택 업로드**(자동 일괄 아님 — 사용자 동의·용량 인지). 해지 시 데이터 영구 보존(콜드 유지), 새 업로드만 중단.

## 10. 구현 단계 (phased)

1. **인프라(사용자 작업)**: R2 계정·버킷·API 토큰, Cloudflare CDN, App Store Connect 구독 상품 2개. (Supabase 프로젝트 `rqlfyumzmpmhupjtroid`는 기존.)
2. DB: `schema_family_feed.sql` + RLS 배포.
3. Edge: `media-upload-url`(presigned), `verify-subscription`.
4. 앱: StoreKit 구독·`isPro` 게이트 → 클라이언트 압축·업로드 → 가족 피드 UI(하트·댓글) → 가족 초대.
5. 안드로이드 웹 뷰어.
6. 무료→Pro 마이그레이션(선택 업로드).

## 11. 사용자(운영자) 선행 작업 체크리스트

- [ ] Cloudflare R2 버킷 + S3 호환 API 토큰 (Secrets로 주입, 코드/깃 노출 금지)
- [ ] Cloudflare CDN(커스텀 도메인 권장) — R2 공개/서명 서빙
- [ ] App Store Connect: 구독 그룹 + 월/연 상품 등록, 가격 ₩990/₩9,900
- [ ] App Store Server API 키(영수증 검증용, service_role급 비밀 — Edge에만)

## 12. 미해결 / 결정 필요

- 영상 서빙: 추측불가키(단순)+CDN vs 짧은수명 signed URL(더 안전). 아동안전상 signed 권장 검토.
- 가족 정원 상한(예: 6~8명) — 비용·UX.
- 무료→Pro 업로드 시 영상 처리(길이캡 초과 기존 영상 안내).
