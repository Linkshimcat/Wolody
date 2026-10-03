// Wolody — 계정 탈퇴
//
// 앱(로그인한 사용자)이 호출하면 그 사용자의 사진(mood-photos/{uid}/)을 지우고
// 계정을 삭제한다. mood_entries·profiles는 auth.users에 on delete cascade라 함께 지워진다.
// 계정 삭제에는 service_role 키가 필요해서 앱이 아닌 이 함수에서 처리한다.
import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "mood-photos";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "unauthorized" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // 토큰 주인만 자기 계정을 지울 수 있다.
  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  // 1. 클라우드 사진. SQL로는 storage.objects를 지울 수 없어 Storage API로 지운다.
  const storage = admin.storage.from(BUCKET);
  while (true) {
    const { data: files, error } = await storage.list(user.id, { limit: 100 });
    if (error) return json({ error: `storage_list: ${error.message}` }, 500);
    if (!files || files.length === 0) break;
    const { error: removeError } = await storage.remove(
      files.map((file) => `${user.id}/${file.name}`),
    );
    if (removeError) {
      return json({ error: `storage_remove: ${removeError.message}` }, 500);
    }
    if (files.length < 100) break;
  }

  // 2. 계정. 기록·프로필은 cascade로 함께 지워진다.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: `delete_user: ${deleteError.message}` }, 500);

  return json({ ok: true });
});
