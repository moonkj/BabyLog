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

  // 2) 본인 콘텐츠는 보존(소유 uuid 고아화 = 익명). 식별만 해제하기 위해 auth 사용자 삭제.
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
