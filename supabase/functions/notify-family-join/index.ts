// Supabase Edge Function: notify-family-join
// 새 가족 합류 신청(승인 대기) → 가족 주인에게 APNs 푸시("○○님이 합류를 요청했어요").
//
// 시크릿(crew 푸시와 공유): APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, APNS_HOST
// 호출: POST { familyId, name } + 헤더 x-device-id = 신청자(ownerID)
//   주인 식별: bl_family.owner_uid. 토큰: crew_push_token(device_id=owner_uid).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-device-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function b64urlToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(b64url.length / 4) * 4, "=");
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}
function bytesToB64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
async function apnsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_KEY")!
    .replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\s/g, "");
  const der = b64urlToBytes(pem.replace(/\+/g, "-").replace(/\//g, "_"));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = bytesToB64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = bytesToB64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const signingInput = `${header}.${claims}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${bytesToB64url(new Uint8Array(sig))}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const payload = await req.json().catch(() => ({}));
    const familyId: string | undefined = payload?.familyId;
    const who = (payload?.name ?? "가족").toString().slice(0, 40);
    if (!familyId) return new Response("missing familyId", { status: 400, headers: CORS });

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // 신원은 검증된 세션 JWT(uid) 우선 — x-device-id 헤더는 위조 가능. 신청자는 앱(로그인) 또는
    //  가족 웹(익명 세션)이라 정상 호출엔 항상 세션 JWT가 있고 uid == ownerID. 세션 없을 때만 헤더 폴백.
    const authToken = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    let verifiedUid: string | null = null;
    if (authToken) {
      try {
        const { data } = await supabase.auth.getUser(authToken);
        verifiedUid = data?.user?.id ?? null;   // anon key/만료 토큰이면 null → 헤더 폴백
      } catch (_) { /* 검증 실패 → 아래에서 거부 */ }
    }
    // 헤더 폴백 제거 — 신청자는 앱(로그인) 또는 가족 웹(익명 세션)이라 항상 검증 uid를 가진다.
    // x-device-id 위조로 타인 사칭 신청·푸시를 막기 위해 검증 uid가 없으면 거부.
    const sender = verifiedUid;
    if (!sender) return new Response(JSON.stringify({ sent: 0, reason: "unauthorized" }), { status: 401, headers: CORS });

    // 가족 주인
    const { data: fam } = await supabase.from("bl_family").select("owner_uid").eq("id", familyId).maybeSingle();
    const owner = fam?.owner_uid;
    if (!owner) return new Response(JSON.stringify({ sent: 0, reason: "no_family" }), { status: 200, headers: CORS });
    if (owner === sender) return new Response(JSON.stringify({ sent: 0, reason: "self" }), { status: 200, headers: CORS });

    // 스팸 방지 — 신청자는 이 가족의 멤버 행(대기 포함)이어야 함.
    // limit(1) — maybeSingle()은 중복 멤버행(레이스로 같은 uid 2행)이 있으면 throw해 푸시가 통째로 누락됐다.
    const { data: mem } = await supabase.from("bl_family_member")
      .select("id").eq("family_id", familyId).eq("uid", sender).limit(1);
    if (!mem?.length) return new Response(JSON.stringify({ sent: 0, reason: "not_member" }), { status: 200, headers: CORS });

    // 주인 토큰
    const { data: tokens } = await supabase.from("crew_push_token").select("apns_token, env").eq("device_id", owner);
    if (!tokens?.length) return new Response(JSON.stringify({ sent: 0, reason: "no_token" }), { status: 200, headers: CORS });

    const jwt = await apnsJWT();
    const fallbackHost = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const body = JSON.stringify({
      aps: { alert: { title: "👶 가족 합류 요청", body: `${who}님이 가족 보관함 합류를 요청했어요. 승인해 주세요.` },
             sound: "default", "thread-id": `family-${familyId}` },
    });
    let sent = 0; const stale: string[] = [];
    for (const t of tokens) {
      const host = t.env === "production" ? "api.push.apple.com"
                 : t.env === "sandbox" ? "api.sandbox.push.apple.com" : fallbackHost;
      try {
        const r = await fetch(`https://${host}/3/device/${t.apns_token}`, {
          method: "POST",
          headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
          body,
          signal: AbortSignal.timeout(5000),
        });
        if (r.ok) { sent++; continue; }
        if (r.status === 410) stale.push(t.apns_token);
      } catch { /* 타임아웃/네트워크 — 건너뜀 */ }
    }
    if (stale.length) await supabase.from("crew_push_token").delete().in("apns_token", stale);
    return new Response(JSON.stringify({ sent, pruned: stale.length }), { status: 200, headers: CORS });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500, headers: CORS });
  }
});
