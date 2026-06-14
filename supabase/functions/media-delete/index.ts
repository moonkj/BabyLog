// Supabase Edge Function: media-delete
// Pro 가족 피드 — 올린 본인이 사진/영상을 '완전 삭제'. R2 원본 객체까지 지운다(DB만 지우면 R2에 고아 객체가 남음).
//
// 권한: 작성자 본인만(post.author_uid == JWT uid). RLS bl_post_delete와 동일 기준을 서버에서 재확인.
// 동작: 1) 포스트의 미디어 키 조회 → 2) R2 객체 삭제(r2_key·thumb_key) → 3) DB 포스트 삭제(미디어·하트·댓글 FK cascade)
//
// 시크릿(media-upload-url과 공유): R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
// 호출: POST { postId }, 헤더 Authorization: Bearer <user JWT>, apikey: <anon>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.18";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  // 1) 사용자 인증
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "no_auth" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) return json({ error: "invalid_token" }, 401);
  const uid = userData.user.id;

  // 2) 입력
  let body: { postId?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_body" }, 400); }
  const postId = body.postId;
  if (!postId) return json({ error: "missing_postId" }, 400);

  // 3) 포스트 + 미디어 조회, 작성자 본인 확인
  const { data: post } = await admin
    .from("bl_feed_post")
    .select("author_uid, bl_post_media(r2_key, thumb_key)")
    .eq("id", postId).maybeSingle();
  if (!post) return json({ error: "not_found" }, 404);
  if (post.author_uid !== uid) return json({ error: "not_author" }, 403);

  // 4) R2 객체 삭제(원본 + 썸네일). 일부 실패해도 계속 진행(베스트에포트) — DB 삭제는 반드시 수행.
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const keys: string[] = [];
  for (const m of (post.bl_post_media ?? []) as Array<{ r2_key?: string; thumb_key?: string }>) {
    if (m.r2_key) keys.push(m.r2_key);
    if (m.thumb_key) keys.push(m.thumb_key);
  }
  if (accountId && bucket && keys.length) {
    const r2 = new AwsClient({
      accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
      secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
      region: "auto", service: "s3",
    });
    for (const key of keys) {
      const url = `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`;
      try { await r2.fetch(url, { method: "DELETE" }); } catch { /* 고아 객체는 추후 정리 */ }
    }
  }

  // 5) DB 포스트 삭제(미디어·하트·댓글 FK cascade)
  const { error: delErr } = await admin.from("bl_feed_post").delete().eq("id", postId);
  if (delErr) return json({ error: `db_delete_failed: ${delErr.message}` }, 500);

  return json({ ok: true, removedObjects: keys.length });
});
