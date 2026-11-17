// kakao-login: Kakao login that asks only for the email (OpenID Connect), not the nickname or profile photo
// that Supabase's built-in Kakao provider always requests (which fails with KOE205 unless those consent
// items are set up).
//
// 1. The app opens  /functions/v1/kakao-login?nonce=<sha256 hex of its raw nonce>&state=<random>
//    → redirect to Kakao's login page (scope openid,account_email).
// 2. Kakao comes back here with ?code → exchanged for an OpenID id_token (server side, with the client secret)
//    → redirect to scoo://auth-callback?id_token=…&state=…
// 3. The app hands the id_token and its raw nonce to Supabase (grant_type=id_token, provider kakao), like Apple.
//    Someone who catches the id_token cannot use it without the raw nonce, which never leaves the phone.
//
// Kakao Developers: OpenID Connect ON, this function's URL added as a Kakao Login redirect URI.
// Secrets (Edge Functions → Secrets): KAKAO_CLIENT_SECRET (the "카카오 로그인 Client Secret", if activated),
// optional KAKAO_REST_API_KEY (defaults to SCOO's REST API key, which is public: it appears in every login URL).
// Deploy with verify_jwt off: Kakao's redirect carries no Supabase token.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CLIENT_ID = Deno.env.get("KAKAO_REST_API_KEY") ?? "0cc091b48d29946f554008b7d0f3f909";
const CLIENT_SECRET = Deno.env.get("KAKAO_CLIENT_SECRET");
// Must match the redirect URI registered at Kakao exactly.
const SELF = "https://ofwexbasbwumfvswkixb.supabase.co/functions/v1/kakao-login";
const APP = "scoo://auth-callback";
const TOKEN_LIKE = /^[A-Za-z0-9._~-]{16,128}$/;

const toApp = (params: Record<string, string>) =>
  new Response(null, { status: 302, headers: { Location: `${APP}?${new URLSearchParams(params)}`, "Cache-Control": "no-store" } });

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const q = url.searchParams;

  // Step 2: Kakao's answer.
  if (q.has("code") || q.has("error")) {
    const state = q.get("state") ?? "";
    if (q.has("error")) {
      return toApp({ error: q.get("error")!, error_description: q.get("error_description") ?? "", state });
    }
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: CLIENT_ID,
      redirect_uri: SELF,
      code: q.get("code")!,
    });
    if (CLIENT_SECRET) body.set("client_secret", CLIENT_SECRET);
    const answer = await fetch("https://kauth.kakao.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
      body,
    });
    const tokens = await answer.json().catch(() => ({}));
    if (!answer.ok) {
      return toApp({ error: tokens.error ?? "kakao_token_failed", error_description: tokens.error_description ?? `${answer.status}`, state });
    }
    if (!tokens.id_token) {
      return toApp({ error: "kakao_oidc_off", error_description: "OpenID Connect is not enabled for the Kakao app", state });
    }
    return toApp({ id_token: tokens.id_token, state });
  }

  // Step 1: send the person to Kakao.
  const nonce = q.get("nonce") ?? "", state = q.get("state") ?? "";
  if (!TOKEN_LIKE.test(nonce) || !TOKEN_LIKE.test(state)) {
    return new Response("nonce and state are required", { status: 400 });
  }
  const kakao = new URL("https://kauth.kakao.com/oauth/authorize");
  kakao.search = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: SELF,
    response_type: "code",
    scope: "openid,account_email",
    nonce,
    state,
  }).toString();
  return new Response(null, { status: 302, headers: { Location: kakao.toString(), "Cache-Control": "no-store" } });
});
