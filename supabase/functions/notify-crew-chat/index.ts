// Supabase Edge Function: notify-crew-chat
// 크루 단체 채팅(모임/그룹) 새 메시지 → 참여자 전원(보낸 사람 제외)에게 APNs 푸시.
//
// 시크릿(notify-crew-open과 공유): APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, APNS_HOST
// 호출: POST { meetup_id?, group_id?, body } + 헤더 x-device-id = 보낸 사람(ownerID)
//   participants: 모임=crew_meetup_join, 그룹=crew_group_member. 토큰: crew_push_token(device_id=ownerID).

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
    const meetupId: string | undefined = payload?.meetup_id;
    const groupId: string | undefined = payload?.group_id;
    const msg: string = (payload?.body ?? "").toString().slice(0, 120);
    const sender = req.headers.get("x-device-id");
    if (!meetupId && !groupId) return new Response("missing id", { status: 400 });

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // 참여자 + 방 이름
    let participants: string[] = [];
    let title = "크루";
    if (meetupId) {
      const { data: joins } = await supabase.from("crew_meetup_join").select("device_id").eq("meetup_id", meetupId);
      participants = (joins ?? []).map((j: any) => j.device_id);
      const { data: m } = await supabase.from("crew_meetup").select("place").eq("id", meetupId).maybeSingle();
      if (m?.place) title = `${m.place} 모임`;
    } else if (groupId) {
      const { data: mem } = await supabase.from("crew_group_member").select("device_id").eq("group_id", groupId);
      participants = (mem ?? []).map((j: any) => j.device_id);
      const { data: g } = await supabase.from("crew_group").select("name").eq("id", groupId).maybeSingle();
      if (g?.name) title = g.name;
    }

    // 보낸 사람만 멤버면 보낼 곳 없음 / 스팸 방지(보낸 사람이 멤버여야 함)
    if (sender && !participants.includes(sender)) return new Response("not member", { status: 403 });
    const recipients = participants.filter((d) => d && d !== sender);
    if (!recipients.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

    const { data: tokens, error: tokErr } = await supabase
      .from("crew_push_token").select("apns_token, env").in("device_id", recipients);
    if (tokErr) throw tokErr;
    if (!tokens?.length) return new Response(JSON.stringify({ sent: 0, reason: "no_token" }), { status: 200 });

    const jwt = await apnsJWT();
    const fallbackHost = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const body = JSON.stringify({
      aps: { alert: { title: `💬 ${title}`, body: msg.length ? msg : "새 메시지가 도착했어요." }, sound: "default",
             "thread-id": meetupId ? `cm-${meetupId}` : `cg-${groupId}` },
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
    return new Response(JSON.stringify({ sent, recipients: recipients.length, pruned: stale.length }), { status: 200 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
