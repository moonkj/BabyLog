// Supabase Edge Function: notify-crew-open
// crew_waitlist INSERT 웹훅으로 호출 → 해당 동네가 목표 인원 도달 & 미오픈이면
// 오픈 처리 후 그 동네 모든 기기에 APNs 푸시 발송(앱이 꺼져 있어도 수신).
//
// 필요한 환경변수(Supabase → Edge Functions → Secrets):
//   APNS_KEY       : .p8 파일 내용(-----BEGIN PRIVATE KEY----- ... 전체)
//   APNS_KEY_ID    : APNs 키 ID (10자)
//   APNS_TEAM_ID   : Apple 팀 ID (예: QN975MTM7H)
//   APNS_TOPIC     : 앱 번들ID (예: com.vibelab.babylog)
//   APNS_HOST      : api.sandbox.push.apple.com (개발) | api.push.apple.com (배포)
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 는 자동 제공)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const THRESHOLD = 30;

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
    // Database Webhook이면 record.hood, 직접 호출이면 hood
    const hood: string | undefined = payload?.record?.hood ?? payload?.hood;
    if (!hood) return new Response("no hood", { status: 400 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1) 카운트
    const { count } = await supabase
      .from("crew_waitlist")
      .select("*", { count: "exact", head: true })
      .eq("hood", hood);
    if ((count ?? 0) < THRESHOLD) return new Response(JSON.stringify({ hood, count, opened: false }), { status: 200 });

    // 2) 오픈 상태(중복 발송 방지)
    const { data: status } = await supabase
      .from("crew_hood_status").select("opened").eq("hood", hood).maybeSingle();
    if (status?.opened) return new Response(JSON.stringify({ hood, alreadyOpened: true }), { status: 200 });
    await supabase.from("crew_hood_status")
      .upsert({ hood, opened: true, opened_at: new Date().toISOString() });

    // 3) 동네 토큰 수집
    const { data: tokens } = await supabase
      .from("crew_push_token").select("apns_token").eq("hood", hood);
    if (!tokens?.length) return new Response(JSON.stringify({ hood, sent: 0 }), { status: 200 });

    // 4) APNs 발송
    const jwt = await apnsJWT();
    const host = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;
    const body = JSON.stringify({
      aps: { alert: { title: `🌱 ${hood} 크루가 열렸어요`, body: "이웃이 충분히 모였어요. 동네 크루를 확인해 보세요." }, sound: "default" },
    });
    let sent = 0;
    for (const t of tokens) {
      const r = await fetch(`https://${host}/3/device/${t.apns_token}`, {
        method: "POST",
        headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
        body,
      });
      if (r.ok) sent++;
    }
    return new Response(JSON.stringify({ hood, count, sent }), { status: 200 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
