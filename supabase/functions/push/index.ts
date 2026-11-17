// push: sends an Apple push notification to every device of one account.
// Called only by the database (queue_push → pg_net) with the shared secret in `x-push-secret`.
//
// Secrets (Edge Functions → Secrets): APNS_KEY (the .p8 file's text), APNS_KEY_ID, APNS_TEAM_ID,
// optional APNS_TOPIC (bundle id, default com.jeongmint.scoo). Without them the function does nothing.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const TOPIC = Deno.env.get("APNS_TOPIC") ?? "com.jeongmint.scoo";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

// APNs provider token (ES256 JWT), reused for 50 minutes as Apple asks.
let cached: { token: string; made: number } | null = null;
async function providerToken(): Promise<string | null> {
  const pem = Deno.env.get("APNS_KEY"), keyId = Deno.env.get("APNS_KEY_ID"), teamId = Deno.env.get("APNS_TEAM_ID");
  if (!pem || !keyId || !teamId) return null;
  if (cached && Date.now() - cached.made < 50 * 60 * 1000) return cached.token;
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const encoder = new TextEncoder();
  const header = base64url(encoder.encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64url(encoder.encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${claims}`));
  cached = { token: `${header}.${claims}.${base64url(new Uint8Array(signature))}`, made: Date.now() };
  return cached.token;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: secret } = await admin.rpc("push_hook_secret");
  if (!secret || req.headers.get("x-push-secret") !== secret) return json({ error: "forbidden" }, 403);

  const { user_id, title, body, kind } = await req.json();
  if (!user_id || !title) return json({ error: "user_id and title" }, 400);

  const jwt = await providerToken();
  if (!jwt) return json({ skipped: "APNs secrets are not set" });

  const { data: devices } = await admin.from("push_tokens").select("token, environment").eq("user_id", user_id);
  let sent = 0;
  for (const device of devices ?? []) {
    const host = device.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
    const answer = await fetch(`https://${host}/3/device/${device.token}`, {
      method: "POST",
      headers: { authorization: `bearer ${jwt}`, "apns-topic": TOPIC, "apns-push-type": "alert", "apns-priority": "10" },
      body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" }, kind }),
    });
    if (answer.ok) { sent++; continue; }
    const reason = (await answer.json().catch(() => ({})))?.reason ?? "";
    console.error("apns", answer.status, reason);
    // The device uninstalled the app or the token is stale: forget it.
    if (answer.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") {
      await admin.from("push_tokens").delete().eq("token", device.token);
    }
  }
  return json({ sent });
});
