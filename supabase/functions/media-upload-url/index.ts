// Supabase Edge Function: media-upload-url
// Pro 가족 피드용 — R2 presigned PUT URL 발급. 미디어 바이트는 우리 컴퓨트/Supabase를
// 거치지 않고 클라이언트 → R2로 직접 업로드한다(트래픽 비용 0의 핵심).
//
// ⚠️ 상태: 설계 초안. R2 인프라 셋업 후 시크릿 등록 + 검증 필요(docs/PRO_FAMILY_FEED.md).
//
// 호출: POST, 헤더 Authorization: Bearer <user JWT>, apikey: <anon>
// 바디: { familyId, kind: "photo"|"video", ext: "jpg"|"mp4", contentType }
// 응답: { uploadUrl, key, publicUrl, expiresIn }
//
// 필요한 환경변수(Supabase → Edge Functions → Secrets):
//   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
//   R2_PUBLIC_BASE  : CDN 공개 베이스 URL (예: https://media.babylog.app)
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 자동 제공)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.18";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  // 1) 사용자 인증 — JWT에서 uid 추출
  const authz = req.headers.get("Authorization") ?? "";
  const jwt = authz.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "no_auth" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) return json({ error: "invalid_token" }, 401);
  const uid = userData.user.id;

  // 2) 입력
  let body: { familyId?: string; kind?: string; ext?: string; contentType?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_body" }, 400); }
  const { familyId, kind, ext, contentType } = body;
  if (!familyId || !kind || !ext) return json({ error: "missing_fields" }, 400);
  if (kind !== "photo" && kind !== "video") return json({ error: "bad_kind" }, 400);
  // ⚠️ 경로탈출/저장형 XSS 방지 — familyId는 UUID, ext는 화이트리스트만 허용하고
  //    kind와 정합(photo↔이미지, video↔영상)을 강제한다. 안 하면 ext에 '../other/x.html'
  //    같은 값으로 가족 prefix 밖에 임의 콘텐츠를 쓸 수 있다.
  if (!/^[0-9a-fA-F-]{36}$/.test(familyId)) return json({ error: "bad_family" }, 400);
  const PHOTO_EXT = ["jpg", "jpeg", "png", "heic"];
  const VIDEO_EXT = ["mp4", "mov"];
  const e = String(ext).toLowerCase();
  const allowed = kind === "video" ? VIDEO_EXT : PHOTO_EXT;
  if (!allowed.includes(e)) return json({ error: "bad_ext" }, 400);

  // 3) 가족 쓰기 권한 (서버 권위 — 읽기 게이트 bl_is_family_member와 동일 기준):
  //    ① 승인된 멤버여야 함(approved) — 승인 대기자 업로드 차단.
  //    ② 주인은 항상, 그 외는 (주인 is_pro) 또는 (무료 배우자 partner_uid)일 때만 — 만료된 조부모 차단.
  const { data: member } = await admin
    .from("bl_family_member").select("id, approved").eq("family_id", familyId).eq("uid", uid).maybeSingle();
  if (!member || member.approved !== true) return json({ error: "not_approved" }, 403);

  const { data: fam } = await admin.from("bl_family")
    .select("owner_uid, partner_uid").eq("id", familyId).maybeSingle();
  let ownerPro = false;
  if (fam?.owner_uid) {
    const { data: prof } = await admin.from("bl_profile")
      .select("is_pro, pro_expires_at").eq("uid", fam.owner_uid).maybeSingle();
    // 만료 반영 — is_pro만 보면 해지/만료 후에도 업로드가 열린다.
    ownerPro = prof?.is_pro === true &&
      (!prof?.pro_expires_at || new Date(prof.pro_expires_at).getTime() > Date.now());
  }
  const isOwner = fam?.owner_uid === uid;
  if (!isOwner && !ownerPro && fam?.partner_uid !== uid) {
    return json({ error: "view_blocked" }, 403);   // 무료 등급 + 배우자 아님(만료 조부모 등) → 업로드 불가
  }

  // 3-1) 영상 개수 상한 — 등급별 무료 100 / Pro 300(주인 is_pro 기준). 저장 비용 통제.
  if (kind === "video") {
    const cap = ownerPro ? 300 : 100;
    const { count } = await admin.from("bl_post_media")
      .select("id", { count: "exact", head: true })
      .eq("family_id", familyId).eq("kind", "video");
    if ((count ?? 0) >= cap) return json({ error: "video_cap", cap }, 403);
  }

  // 4) R2 presigned PUT URL (10분)
  const accountId = Deno.env.get("R2_ACCOUNT_ID")!;
  const bucket = Deno.env.get("R2_BUCKET")!;
  const key = `${familyId}/${crypto.randomUUID()}.${e}`;   // 검증된 소문자 확장자만 사용
  const endpoint = `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`;

  const r2 = new AwsClient({
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
    region: "auto",
    service: "s3",
  });
  const expiresIn = 600;
  const signed = await r2.sign(
    new Request(endpoint, { method: "PUT", headers: contentType ? { "content-type": contentType } : {} }),
    { aws: { signQuery: true }, expires: expiresIn },
  );

  const publicBase = (Deno.env.get("R2_PUBLIC_BASE") ?? "").replace(/\/+$/, "");
  return json({
    uploadUrl: signed.url,
    key,
    publicUrl: `${publicBase}/${key}`,
    expiresIn,
  });
});
