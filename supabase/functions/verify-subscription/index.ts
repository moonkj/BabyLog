// Supabase Edge Function: verify-subscription
// StoreKit 2 Pro 구독을 App Store Server API로 서버 검증 → profile.is_pro 갱신.
// 클라이언트 isPro만 믿지 않고(우회 방지) 서버가 권위적으로 판정한다.
//
// ⚠️ 상태: 설계 초안. App Store Connect 구독 상품 + In-App Purchase 키 발급 후 검증 필요.
//    (docs/PRO_FAMILY_FEED.md §7). 운영 전 sandbox/prod 분기·재시도·서명체인 검증 점검.
//
// 호출: POST, Authorization: Bearer <user JWT>, 바디 { transactionId }
// 응답: { isPro, expiresAt }
//
// 환경변수(Secrets):
//   APPLE_IAP_KEY     : App Store Server API .p8 내용(BEGIN PRIVATE KEY ... 전체)
//   APPLE_IAP_KEY_ID  : 키 ID
//   APPLE_ISSUER_ID   : Issuer ID (App Store Connect → 통합)
//   APP_BUNDLE_ID     : com.vibelab.babylog
//   APPLE_API_HOST    : api.storekit.itunes.apple.com(prod) | api.storekit-sandbox.itunes.apple.com
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 자동 제공)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });

function b64url(bytes: Uint8Array): string {
  let bin = ""; for (const x of bytes) bin += String.fromCharCode(x);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlDecode(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// App Store Server API용 ES256 JWT 생성(notify-crew-open APNs JWT와 동일 기법).
async function appleApiJWT(): Promise<string> {
  const keyId = Deno.env.get("APPLE_IAP_KEY_ID")!;
  const issuer = Deno.env.get("APPLE_ISSUER_ID")!;
  const bundle = Deno.env.get("APP_BUNDLE_ID")!;
  const pem = Deno.env.get("APPLE_IAP_KEY")!
    .replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\s/g, "");
  const der = b64urlDecode(pem.replace(/\+/g, "-").replace(/\//g, "_"));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" })));
  const claims = b64url(new TextEncoder().encode(JSON.stringify({
    iss: issuer, iat: now, exp: now + 1800, aud: "appstoreconnect-v1", bid: bundle,
  })));
  const signingInput = `${header}.${claims}`;
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

// Apple이 돌려주는 JWS의 payload(가운데 세그먼트)만 디코딩(응답은 TLS+API인증 경유라 신뢰).
function decodeJWSPayload(jws: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(b64urlDecode(jws.split(".")[1])));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "no_auth" }, 401);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) return json({ error: "invalid_token" }, 401);
  const uid = userData.user.id;

  let body: { transactionId?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_body" }, 400); }
  const txId = body.transactionId;
  if (!txId) return json({ error: "missing_transactionId" }, 400);

  // App Store Server API — 구독 상태 조회
  const host = Deno.env.get("APPLE_API_HOST") ?? "api.storekit.itunes.apple.com";
  const apiJwt = await appleApiJWT();
  const res = await fetch(`https://${host}/inApps/v1/subscriptions/${txId}`, {
    headers: { Authorization: `Bearer ${apiJwt}` },
  });
  if (!res.ok) return json({ error: "apple_api", status: res.status }, 502);

  // 응답에서 최신 거래의 만료일 추출(가장 가까운 그룹의 lastTransactions)
  const data = await res.json();
  let expiresMs = 0;
  for (const g of data.data ?? []) {
    for (const t of g.lastTransactions ?? []) {
      if (!t.signedTransactionInfo) continue;
      const info = decodeJWSPayload(t.signedTransactionInfo);
      const exp = Number(info.expiresDate ?? 0);
      if (exp > expiresMs) expiresMs = exp;
    }
  }
  const isPro = expiresMs > Date.now();
  const expiresAt = expiresMs > 0 ? new Date(expiresMs).toISOString() : null;

  // bl_profile.is_pro 갱신(서버 권위)
  await admin.from("bl_profile").upsert({ uid, is_pro: isPro, pro_expires_at: expiresAt }, { onConflict: "uid" });

  return json({ isPro, expiresAt });
});
