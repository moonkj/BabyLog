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

    // 2) APNs JWT를 게이트 클레임 '전에' 생성 — 시크릿 미설정/형식 오류로 throw해도
    //    게이트(opened=true)가 소모되지 않아 푸시가 영구 유실되지 않는다.
    const jwt = await apnsJWT();
    const fallbackHost = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
    const topic = Deno.env.get("APNS_TOPIC")!;

    // 3) 오픈 상태 — 원자적 게이트(동시 호출 중복 발송 방지: 웹훅 + 클라 직접호출 레이스)
    //    행 없으면 생성(opened=false) → opened=false인 동안만 true로 전환(UPDATE...WHERE)되어
    //    딱 한 호출만 성공. 성공한 호출만 푸시를 발송한다.
    await supabase.from("crew_hood_status")
      .upsert({ hood }, { onConflict: "hood", ignoreDuplicates: true });
    const { data: claimed } = await supabase.from("crew_hood_status")
      .update({ opened: true, opened_at: new Date().toISOString() })
      .eq("hood", hood).eq("opened", false).select("hood");
    if (!claimed || claimed.length === 0) {
      return new Response(JSON.stringify({ hood, alreadyOpened: true }), { status: 200 });
    }

    // 4) 발송 섹션(토큰 수집~발송 루프~stale 정리) — 실패 시 게이트를 되돌린다.
    //    게이트(opened=true)만 소모하고 발송이 throw하면 푸시가 영구 유실되므로,
    //    실패하면 opened=false로 롤백 후 500을 반환해 다음 호출이 재시도하게 한다.
    try {
      // 동네 토큰 수집 (env 포함 — 토큰별로 샌드박스/운영 호스트를 다르게 보냄)
      const { data: tokens, error: tokErr } = await supabase
        .from("crew_push_token").select("apns_token, env").eq("hood", hood);
      if (tokErr) throw tokErr;   // 조회 실패를 '토큰 0개'로 오인해 게이트만 소모하지 않도록 throw
      if (!tokens?.length) return new Response(JSON.stringify({ hood, sent: 0 }), { status: 200 });

      // APNs 발송 — 호스트는 토큰의 env로 결정(개발=샌드박스, 배포=운영).
      //    빌드 구성별로 토큰이 자동 태깅되므로 APNS_HOST 수동 전환이 필요 없다.
      //    env가 없는 레거시 행은 APNS_HOST(없으면 샌드박스)로 폴백.
      const body = JSON.stringify({
        aps: { alert: { title: `🌱 ${hood} 크루가 열렸어요`, body: "이웃이 충분히 모였어요. 동네 크루를 확인해 보세요." }, sound: "default" },
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
        if (r.ok) { sent++; continue }
        // 410 Unregistered → 만료 토큰. 정리해 테이블 무한 증가 방지.
        if (r.status === 410) stale.push(t.apns_token);
      }
      if (stale.length) {
        await supabase.from("crew_push_token").delete().in("apns_token", stale);
      }
      return new Response(JSON.stringify({ hood, count, sent, pruned: stale.length }), { status: 200 });
    } catch (sendErr) {
      // 발송 실패 → 게이트 롤백(opened=false). 다음 호출(웹훅/앱)이 다시 발송을 시도한다.
      await supabase.from("crew_hood_status")
        .update({ opened: false, opened_at: null })
        .eq("hood", hood);
      return new Response(`send error (gate rolled back): ${sendErr}`, { status: 500 });
    }
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
