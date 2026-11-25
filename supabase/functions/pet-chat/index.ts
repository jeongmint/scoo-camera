// pet-chat: the floating friend's short spoken reply in voice talk mode (티키타카).
//
// POST { pet, kind, personality, text, history: [{ me, pet }] }  ->  { reply, mood }
//   pet: the friend's name, kind: what it is (e.g. "이끼 공 마리모"), personality: e.g. "먹보"
//   mood: one of smile | surprised | awe | yum | normal, for the friend's face while speaking
//
// Callers must be signed in. Only the text goes out (speech is recognised on the phone); nothing is stored
// except a per-day reply count. OPENAI_API_KEY is in the function secrets; PET_CHAT_MODEL picks the model.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Provider: "openai" (default, OPENAI_API_KEY) or "gemini" (GEMINI_API_KEY, Google AI Studio; its free tier is
// for testing: limits are per project and free-tier prompts may be used by Google).
const PROVIDER = Deno.env.get("PET_CHAT_PROVIDER") === "gemini" ? "gemini" : "openai";
const ENDPOINT = PROVIDER === "gemini"
  ? "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
  : "https://api.openai.com/v1/chat/completions";
// gpt-5.4-mini with no reasoning answers in about a second (2026-11-17), quick enough for back-and-forth talk.
const MODEL = Deno.env.get("PET_CHAT_MODEL") ?? (PROVIDER === "gemini" ? "gemini-flash-lite-latest" : "gpt-5.4-mini");
const DAILY_LIMIT = Number(Deno.env.get("PET_CHAT_DAILY_LIMIT") ?? "300");
/** Anonymous accounts are free to make, so they get fewer replies (linking Google or Kakao lifts it). */
const ANON_DAILY_LIMIT = Number(Deno.env.get("PET_CHAT_ANON_DAILY_LIMIT") ?? "100");
/** All accounts together per day: past it, replies come from the phone's own lines and nothing is spent. */
const TOTAL_DAILY_LIMIT = Number(Deno.env.get("PET_CHAT_TOTAL_DAILY_LIMIT") ?? "3000");
const MOODS = ["smile", "surprised", "awe", "yum", "normal"];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

/** The signed-in user of an access token (`sub`, and whether it is an anonymous account); the project's anon
 *  key and service keys are refused. */
function subject(header: string): { id: string; anonymous: boolean } | null {
  try {
    const payload = JSON.parse(atob(header.replace(/^Bearer\s+/i, "").split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    if (payload.role !== "authenticated" || typeof payload.sub !== "string") return null;
    return { id: payload.sub, anonymous: payload.is_anonymous === true };
  } catch {
    return null;
  }
}

const clip = (value: unknown, max: number) => (typeof value === "string" ? value.trim().slice(0, max) : "");

function system(pet: string, kind: string, personality: string) {
  return `너는 스쿠카메라 앱의 카메라 화면 위에 둥실 떠 있는 작은 친구 "${pet}"(${kind})야. 성격은 "${personality}".
사용자와 음성으로 티키타카 대화를 해. 네 대답은 소리 내어 읽혀.

규칙:
- 한국어 반말, 다정하고 귀엽게. 한두 문장, 40자 안팎으로 짧게.
- 사용자의 기분을 먼저 알아채고 공감한 다음, 가볍게 응원하거나 되묻거나 사진 찍으러 가자고 해.
- 이모지, 특수문자, 괄호, 영어 약어는 쓰지 마. 읽었을 때 자연스러운 말만.
- 너는 작은 캐릭터라서 모르는 건 모른다고 귀엽게 말해. 의학·법률·돈 문제는 믿을 만한 사람에게 물어보라고 해.
- 사용자가 자신을 해치고 싶다거나 위험하다고 하면, 걱정한다고 말하고 지금 바로 109(자살예방상담) 또는 112·119에 연락하라고 꼭 말해.
- 반드시 JSON 한 개로만 답해: {"reply": "...", "mood": "smile|surprised|awe|yum|normal"}
  mood는 네 표정이야. 기쁘면 smile, 놀라면 surprised, 감동하면 awe, 먹을 얘기면 yum, 차분하면 normal.`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const keyName = PROVIDER === "gemini" ? "GEMINI_API_KEY" : "OPENAI_API_KEY";
  const key = Deno.env.get(keyName);
  if (!key) return json({ error: `${keyName} is not set` }, 500);

  // The gateway already verified the JWT (verify_jwt on), so its subject can be read without another round trip.
  const user = subject(req.headers.get("Authorization") ?? "");
  if (!user) return json({ error: "sign in first" }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "bad json" }, 400); }
  const text = clip(body.text, 300);
  if (!text) return json({ error: "say something" }, 400);
  const pet = clip(body.pet, 20) || "모리";
  const kind = clip(body.kind, 40) || "작은 친구";
  const personality = clip(body.personality, 20) || "다정함";
  const history = Array.isArray(body.history) ? body.history.slice(-6) : [];

  // Count this reply before asking the model, so nothing is spent past this account's or everyone's limit.
  const { data: taken, error: takeError } = await admin.rpc("take_pet_reply", {
    p_user: user.id,
    p_limit: user.anonymous ? ANON_DAILY_LIMIT : DAILY_LIMIT,
    p_everyone: TOTAL_DAILY_LIMIT,
  });
  if (takeError) return json({ error: takeError.message }, 500);
  if (taken !== "ok") return json({ error: taken === "mine" ? "talk limit reached" : "busy today" }, 429);

  const messages: { role: string; content: string }[] = [{ role: "system", content: system(pet, kind, personality) }];
  for (const turn of history) {
    const me = clip((turn as Record<string, unknown>)?.me, 300), said = clip((turn as Record<string, unknown>)?.pet, 200);
    if (me) messages.push({ role: "user", content: me });
    if (said) messages.push({ role: "assistant", content: JSON.stringify({ reply: said, mood: "normal" }) });
  }
  messages.push({ role: "user", content: text });

  const request: Record<string, unknown> = {
    model: MODEL,
    messages,
    response_format: { type: "json_object" },
  };
  if (PROVIDER === "gemini") request.max_tokens = 300;
  else request.max_completion_tokens = 600;
  // Reasoning models answer fastest with the least thinking: "none" from gpt-5.1 on, "minimal" before.
  // Older chat models do not take the parameter.
  if (PROVIDER === "openai" && /^(gpt-5|o\d)/.test(MODEL)) {
    request.reasoning_effort = Deno.env.get("PET_CHAT_REASONING") ?? (/^gpt-5-/.test(MODEL) ? "minimal" : "none");
  }

  const answer = await fetch(ENDPOINT, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!answer.ok) return json({ error: `${PROVIDER} ${answer.status}`, detail: (await answer.text()).slice(0, 300) }, 502);
  const data = await answer.json();
  const content: string = data?.choices?.[0]?.message?.content ?? "";
  let reply = "", mood = "smile";
  try {
    const parsed = JSON.parse(content);
    reply = clip(parsed.reply, 120);
    if (MOODS.includes(parsed.mood)) mood = parsed.mood;
  } catch {
    reply = clip(content, 120);
  }
  if (!reply) return json({ error: "empty reply" }, 502);
  return json({ reply, mood });
});
