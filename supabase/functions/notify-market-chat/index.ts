// Supabase Edge Function: notify-market-chat
// 마켓 1:1 채팅 메시지 전송 시 상대방 기기에 APNs 푸시(앱 꺼져 있어도 수신, 당근식).
//
// 시크릿(notify-crew-open과 공유): APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, APNS_HOST
// 호출: POST { item_id, buyer, body } + 헤더 x-device-id = 보낸 사람
//   스레드 키 = (item_id, buyer). 참여자 = 판매자(item.seller) + 구매자(buyer). 수신자 = 보낸 사람의 반대편.

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
  try {
    const payload = await req.json().catch(() => ({}));
    const itemId: string | undefined = payload?.item_id;
    const buyer: string | undefined = payload?.buyer;
    const msg: string = (payload?.body ?? "").toString().slice(0, 120);
    if (!itemId || !buyer) return new Response("missing", { status: 400 });
    const caller = req.headers.get("x-device-id");

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: item } = await supabase.from("market_item").select("title, seller").eq("id", itemId).maybeSingle();
    if (!item) return new Response("no item", { status: 404 });

    // 참여자 검증 + 수신자 결정(보낸 사람의 반대편)
    if (caller !== item.seller && caller !== buyer) return new Response("not participant", { status: 403 });
    const recipient = caller === item.seller ? buyer : item.seller;

    const { data: tokens, error: tokErr } = await supabase
      .from("crew_push_token").select("apns_token, env").eq("device_id", recipient);
    if (tokErr) throw tokErr;
    if (!tokens?.length) return new Response(JSON.stringify({ sent: 0, reason: "no_token" }), { status: 200 });

    const jwt = await apnsJWT();
    const fallbackHost = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const body = JSON.stringify({
      aps: {
        alert: { title: `💬 ${item.title ?? "마켓"} 문의`, body: msg.length ? msg : "새 메시지가 도착했어요." },
        sound: "default", "thread-id": `mk-${itemId}`,
      },
    });
    let sent = 0; const stale: string[] = [];
    for (const t of tokens) {
      const host = t.env === "production" ? "api.push.apple.com"
                 : t.env === "sandbox" ? "api.sandbox.push.apple.com" : fallbackHost;
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
