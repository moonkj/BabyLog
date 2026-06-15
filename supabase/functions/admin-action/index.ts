// Supabase Edge Function: admin-action
// 운영자 전용 — 콘텐츠 조회/삭제(service_role로 RLS 우회). 비밀번호(ADMIN_PASS)로 게이트.
// 익명(비로그인)으로 만들어 신원이 바뀌어 본인도 못 지우는 모임/크루/매물을 운영자가 정리.
//
// 권한: 호출자 Apple JWT의 uid가 ADMIN_UIDS(쉼표구분 시크릿)에 있어야 함. 미설정 시 fail-closed(500).
// 호출(헤더 Authorization: Bearer <user JWT>):
//   POST { op: "list" } → { meetups, groups, items, posts } 최근순
//   POST { op: "delete", kind, id } → 해당 행 삭제(자식 FK는 on delete cascade)
//     kind ∈ crew_meetup | crew_group | market_item | crew_post

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DELETABLE: Record<string, string> = {
  crew_meetup: "crew_meetup",
  crew_group: "crew_group",
  market_item: "market_item",
  crew_post: "crew_post",
};

Deno.serve(async (req) => {
  try {
    const { op, kind, id, year } = await req.json().catch(() => ({}));

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

    if (op === "stats") {
      // 접속 통계 — 운영자(allow) device_id는 카운트에서 제외. 연도 미지정 시 KST 올해.
      const yr = Number.isFinite(year) ? Number(year) : new Date().getUTCFullYear();
      const { data, error } = await supabase.rpc("bl_admin_stats", { p_year: yr, p_exclude: allow });
      if (error) return new Response(`stats failed: ${error.message}`, { status: 500 });
      return new Response(JSON.stringify(data ?? {}), {
        status: 200, headers: { "content-type": "application/json" },
      });
    }

    if (op === "delete") {
      const table = DELETABLE[kind];
      if (!table || !id) return new Response("bad request", { status: 400 });
      const { error } = await supabase.from(table).delete().eq("id", id);
      if (error) return new Response(`delete failed: ${error.message}`, { status: 500 });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200, headers: { "content-type": "application/json" },
      });
    }

    // 기본: list
    const [meetups, groups, items, posts] = await Promise.all([
      supabase.from("crew_meetup")
        .select("id,title,hood,host_name,when_text,created_at,expires_at")
        .order("created_at", { ascending: false }).limit(100),
      supabase.from("crew_group")
        .select("id,name,hood,creator_name,created_at")
        .order("created_at", { ascending: false }).limit(100),
      supabase.from("market_item")
        .select("id,title,hood,city,seller_name,status,created_at")
        .order("created_at", { ascending: false }).limit(100),
      supabase.from("crew_post")
        .select("id,title,hood,author_name,category,created_at")
        .order("created_at", { ascending: false }).limit(100),
    ]);
    return new Response(JSON.stringify({
      meetups: meetups.data ?? [],
      groups: groups.data ?? [],
      items: items.data ?? [],
      posts: posts.data ?? [],
    }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
