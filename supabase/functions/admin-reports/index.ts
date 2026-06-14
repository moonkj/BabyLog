// Supabase Edge Function: admin-reports
// 운영자 전용 — 신고 목록 조회(service_role로 RLS 우회). 비밀번호로 게이트.
// bl_report는 SELECT 정책이 없어 일반 사용자는 조회 불가 → 이 함수로만 열람.
//
// 시크릿: ADMIN_PASS (미설정 시 기본값 사용 — 솔로 운영 MVP). 출시 전 시크릿으로 교체 권장.
// 호출: POST { pass }  → 최근 신고 200건 반환(권한 없으면 403).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const { pass } = await req.json().catch(() => ({}));
    const expected = Deno.env.get("ADMIN_PASS") ?? "1639316";
    if (!pass || pass !== expected) return new Response("forbidden", { status: 403 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    // 채팅/사용자 신고(bl_report)
    const { data: a } = await supabase
      .from("bl_report")
      .select("id,reporter,reported,reported_name,surface,context_id,reason,note,created_at")
      .order("created_at", { ascending: false }).limit(150);
    // 마켓 거래 신고(market_report) — 공통 형태로 매핑
    const { data: b } = await supabase
      .from("market_report")
      .select("id,item_id,item_title,reporter,counterpart,reason,note,created_at")
      .order("created_at", { ascending: false }).limit(80);
    const mapped = (b ?? []).map((r: any) => ({
      id: r.id, reporter: r.reporter, reported: null, reported_name: r.counterpart,
      surface: "market_item", context_id: r.item_id, reason: r.reason,
      note: [r.item_title, r.note].filter(Boolean).join(" · "), created_at: r.created_at,
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
