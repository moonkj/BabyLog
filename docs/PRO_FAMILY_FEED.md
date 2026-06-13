# Pro 가족 피드 — 설계 (클라우드 가족 보관함)

> 상태: **설계 단계(미구축)**. 인프라(Cloudflare R2, App Store Connect 구독 상품) 셋업이 선행돼야 구현 착수.
> 값 사다리 확정본은 `SPEC.md` > "값 사다리 — 무료 vs Pro" 참조. 결정 맥락은 메모리 `family-photo-sharing`.

## 1. 한 줄 요약

큰 전제는 **사진(+영상) 업로드 모델**.
- **무료** = 나 혼자 보는 개인 저널 (미디어 = 로컬/iCloud, 우리 서버 미사용). 소셜 없음(즐겨찾기 ⭐만).
- **Pro "클라우드 가족 보관함"** = 우리 서버에 올려 **가족 모두가 보고 하트·댓글**(양방향) + **풀화질 영구 백업**. 업로드 1회가 공유와 백업을 동시 해결. 영상 포함(안드로이드 조부모도 시청).

## 2. 절대 지킬 원칙 (CLAUDE.md)

- 아동 안전: 가족 피드는 **초대된 가족만** 접근(공개 아님). 미디어 URL은 추측 불가 키 + 가족 토큰 게이트.
- 데이터 비매각 / 무광고. 무료 데이터 영구 보존(무료는 서버에 없음 — 로컬/iCloud).
- "사진은 서버에 안 올림"은 **무료** 약속. **Pro는 명시적 서버 백업 동의** 위에서만 업로드(원칙과 일치 — "서버 백업은 Pro 혜택").
- 영상은 **Pro 전용**. 무료엔 서버 영상 없음.

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

## 6. 비용 가드 (월 3,900원 유지, 마진 ~90%)

- 미디어 = **R2 + Cloudflare CDN(egress 무료)**. ⚠️ Supabase Storage/S3로 영상 서빙 금지.
- 720p·길이캡·월 업로드 합리적 상한.
- 무료 사용자에겐 서버 미디어 서빙 안 함.
- 추정: 가정당 월 원가 ~$0.1~0.15(저장+DB), 영상 재시청 무관(R2 egress 0). 자세한 계산은 메모리 `family-photo-sharing`.

## 7. 구독 (StoreKit 2)

- 상품: `com.vibelab.babylog.pro.monthly`(₩3,900), `...pro.yearly`(₩29,000). App Store Connect 등록 필요.
- 클라이언트: `Transaction.currentEntitlements`로 Pro 활성 확인 → `isPro` 게이트(가족 생성·업로드 노출).
- 서버: Edge Function `verify-subscription`이 App Store Server API(JWS)로 검증 → `profile.is_pro` 갱신. **업로드/가족 생성 Edge에서 is_pro 재확인**(클라이언트 우회 방지).
- 정직 결제(CLAUDE.md): 자동결제 사전 고지, 해지 쉽고 존중 톤. 다크패턴 금지.

## 8. 안드로이드 조부모

- 경량 **웹 뷰어**(Cloudflare Pages 정적): 가족 초대 링크의 토큰으로 피드 read + 하트·댓글 write(가족 게스트 토큰). 미디어는 R2/CDN. Apple ID 불필요.
- v1은 read+react 우선, 업로드는 iOS 가족만(후속에서 웹 업로드 검토).

## 9. 무료 ↔ Pro 경계

- 무료: 기존 로컬 기록 + 즐겨찾기(⭐). 가족 공유는 iCloud 수동 일방향(`FamilyShareScreen`)만.
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
- [ ] App Store Connect: 구독 그룹 + 월/연 상품 등록, 가격 ₩3,900/₩29,000
- [ ] App Store Server API 키(영수증 검증용, service_role급 비밀 — Edge에만)

## 12. 미해결 / 결정 필요

- 영상 서빙: 추측불가키(단순)+CDN vs 짧은수명 signed URL(더 안전). 아동안전상 signed 권장 검토.
- 가족 정원 상한(예: 6~8명) — 비용·UX.
- 무료→Pro 업로드 시 영상 처리(길이캡 초과 기존 영상 안내).
