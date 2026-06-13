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

  // 3) Pro 여부 + 가족 멤버십 확인 (서버 권위 — 클라이언트 우회 차단)
  const { data: profile } = await admin.from("profile").select("is_pro").eq("uid", uid).maybeSingle();
  if (!profile?.is_pro) return json({ error: "not_pro" }, 403);

  const { data: member } = await admin
    .from("family_member").select("id").eq("family_id", familyId).eq("uid", uid).maybeSingle();
  if (!member) return json({ error: "not_member" }, 403);

  // 4) R2 presigned PUT URL (10분)
  const accountId = Deno.env.get("R2_ACCOUNT_ID")!;
  const bucket = Deno.env.get("R2_BUCKET")!;
  const key = `${familyId}/${crypto.randomUUID()}.${ext}`;
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
