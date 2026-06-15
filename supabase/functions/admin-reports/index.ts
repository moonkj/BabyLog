// Supabase Edge Function: admin-reports
// 운영자 전용 — 신고 목록 조회(service_role로 RLS 우회). 비밀번호로 게이트.
// bl_report는 SELECT 정책이 없어 일반 사용자는 조회 불가 → 이 함수로만 열람.
//
// 권한: 호출자 Apple JWT의 uid가 ADMIN_UIDS(쉼표구분 시크릿)에 있어야 함. 미설정 시 fail-closed(500).
// 호출: POST (헤더 Authorization: Bearer <user JWT>) → 최근 신고 반환(권한 없으면 403).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    // 운영자 화이트리스트(JWT uid) — 하드코딩 비번 제거.
    const allow = (Deno.env.get("ADMIN_UIDS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
    if (!allow.length) return new Response("admin not configured", { status: 500 });
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: u } = await supabase.auth.getUser(jwt);
    if (!u?.user || !allow.includes(u.user.id)) return new Response("forbidden", { status: 403 });
    // 채팅/사용자 신고(bl_report)
    const { data: a } = await supabase
      .from("bl_report")
      .select("id,reporter,reported,reported_name,surface,context_id,reason,note,transcript,created_at")
      .order("created_at", { ascending: false }).limit(150);
    // 마켓 거래 신고(market_report) — 공통 형태로 매핑
    const { data: b } = await supabase
      .from("market_report")
      .select("id,item_id,item_title,reporter,counterpart,reason,note,transcript,created_at")
      .order("created_at", { ascending: false }).limit(80);
    const mapped = (b ?? []).map((r: any) => ({
      id: r.id, reporter: r.reporter, reported: null, reported_name: r.counterpart,
      surface: "market_item", context_id: r.item_id, reason: r.reason,
      note: [r.item_title, r.note].filter(Boolean).join(" · "),
      transcript: r.transcript, created_at: r.created_at,
    }));
    const reports = [...(a ?? []), ...mapped]
      .sort((x: any, y: any) => (y.created_at ?? "").localeCompare(x.created_at ?? ""));
    return new Response(JSON.stringify({ reports }), {
      status: 200, headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
