// delete-account — Sign in with Apple 계정 삭제(Apple 가이드라인 의무)
// 호출자(로그인 사용자)의 JWT로 본인 인증 → service_role로 auth 사용자 삭제.
// ⚠️ 작성 콘텐츠는 "영구 보존" 원칙에 따라 삭제하지 않는다(소유 uuid만 고아화 = 익명).
//    본인 식별만 끊는다. (CLAUDE.md: 무료 데이터 영구 보존 / 데이터 인질극 금지)
//
// 배포:
//   supabase functions deploy delete-account
//   (시크릿) SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 는 플랫폼이 기본 주입.
//   앱은 Authorization: Bearer <user access_token> 로 호출(apikey=anon).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return new Response("Missing token", { status: 401 });

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

  // 1) 토큰으로 본인 확인
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return new Response("Invalid token", { status: 401 });
  }
  const userId = userData.user.id;

  // 2) 활성 매물은 판매완료 처리 — 삭제 후 아무도 관리할 수 없는 '유령 매물'이
  //    최대 30일간 동네에 노출되는 것을 방지(콘텐츠 자체는 보존).
  await admin.from("market_item")
    .update({ status: "판매완료" })
    .eq("seller", userId)
    .in("status", ["판매중", "예약중"]);

  // 3) 표시명 스크럽 — 콘텐츠 본문은 보존(데이터 보존 원칙)하되, 닉네임 등 표시명만 '이웃'으로
  //    익명화한다. auth 사용자만 지우면 소유 uuid는 고아화되지만 author_name 류에 실명/닉네임이
  //    잔존해 식별이 가능하므로, 삭제 전 식별자를 제거한다. (실제 스키마 컬럼 기준:
  //    crew_post·crew_post_reply=author/author_name, crew_meetup=host/host_name,
  //    crew_meetup_message·market_chat_message=device_id/author_name,
  //    crew_group=creator/creator_name, market_item=seller/seller_name)
  const scrubTargets: { table: string; owner: string; nameCol: string }[] = [
    { table: "crew_post",           owner: "author",    nameCol: "author_name" },
    { table: "crew_post_reply",     owner: "author",    nameCol: "author_name" },
    { table: "crew_meetup",         owner: "host",      nameCol: "host_name" },
    { table: "crew_meetup_message", owner: "device_id", nameCol: "author_name" },
    { table: "crew_group",          owner: "creator",   nameCol: "creator_name" },
    { table: "market_item",         owner: "seller",    nameCol: "seller_name" },
    { table: "market_chat_message", owner: "device_id", nameCol: "author_name" },
  ];
  for (const t of scrubTargets) {
    // best-effort — 한 테이블 실패가 계정 삭제 자체를 막지 않도록 오류는 기록만.
    const { error } = await admin.from(t.table)
      .update({ [t.nameCol]: "이웃" })
      .eq(t.owner, userId);
    if (error) console.error(`scrub ${t.table}.${t.nameCol} failed: ${error.message}`);
  }

  // 4) 본인 콘텐츠는 보존(소유 uuid 고아화 = 익명). 식별만 해제하기 위해 auth 사용자 삭제.
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    return new Response(JSON.stringify({ error: delErr.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ deleted: true, user: userId }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
