// Supabase Edge Function: notify-trade-confirm
// 판매자가 매물을 '판매완료 + 구매자 지정'하면 앱이 이 함수를 호출 →
// 지정된 구매자의 기기에 APNs 푸시("거래를 확인해 주세요")를 발송(앱이 꺼져 있어도 수신, 당근식).
//
// 시크릿(notify-crew-open과 공유): APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, APNS_HOST
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 자동 제공)
//
// 호출: POST { item_id }  + 헤더 x-device-id = 판매자 식별자(스팸 방지: 매물 seller와 대조)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = b64urlToBytes(pem.replace(/\+/g, "-").replace(/\//g, "_"));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const header = bytesToB64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = bytesToB64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const signingInput = `${header}.${claims}`;
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${bytesToB64url(new Uint8Array(sig))}`;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json().catch(() => ({}));
    const itemId: string | undefined = payload?.item_id;
    if (!itemId) return new Response("no item_id", { status: 400 });
    const caller = req.headers.get("x-device-id");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1) 매물 조회 — 구매자(sold_to)·판매자·상태 확인
    const { data: item } = await supabase
      .from("market_item")
      .select("title, seller, sold_to, status, buyer_confirmed")
      .eq("id", itemId).maybeSingle();
    if (!item) return new Response("no item", { status: 404 });

    // 2) 스팸 방지 — 호출자(헤더)가 그 매물 판매자여야 함. 헤더 누락 시에도 거부(우회 차단).
    if (!caller || caller !== item.seller) {
      return new Response("not seller", { status: 403 });
    }
    // 3) 보낼 조건: 판매완료 + 구매자 지정 + 아직 미확인
    if (item.status !== "판매완료" || !item.sold_to || item.buyer_confirmed) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    // 4) 구매자 토큰
    const { data: tokens, error: tokErr } = await supabase
      .from("crew_push_token").select("apns_token, env").eq("device_id", item.sold_to);
    if (tokErr) throw tokErr;
    if (!tokens?.length) return new Response(JSON.stringify({ sent: 0, reason: "no_token" }), { status: 200 });

    // 5) APNs 발송
    const jwt = await apnsJWT();
    const fallbackHost = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const body = JSON.stringify({
      aps: {
        alert: {
          title: "거래를 확인해 주세요",
          body: `‘${item.title ?? "거래"}’ 판매자가 거래를 완료로 표시했어요. 거래가 끝났다면 확인해 주세요.`,
        },
        sound: "default",
      },
    });
    let sent = 0;
    const stale: string[] = [];
    for (const t of tokens) {
      const host = t.env === "production" ? "api.push.apple.com"
                 : t.env === "sandbox" ? "api.sandbox.push.apple.com"
                 : fallbackHost;
      const r = await fetch(`https://${host}/3/device/${t.apns_token}`, {
        method: "POST",
        headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
        body,
      });
      if (r.ok) { sent++; continue; }
      if (r.status === 410) stale.push(t.apns_token);
    }
    if (stale.length) await supabase.from("crew_push_token").delete().in("apns_token", stale);
    return new Response(JSON.stringify({ sent, pruned: stale.length }), { status: 200 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
