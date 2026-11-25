// breed-image: draws a bred baby with OpenAI's image model, once per pair, and shares it with everyone.
//
// POST { parentA, parentB, imageA, imageB }  (images: base64 PNG of the two parents, A first)
// -> { url, cached }
//
// The OpenAI key lives only in this function's secrets (OPENAI_API_KEY). Callers must be signed in.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const MODEL = Deno.env.get("BREED_IMAGE_MODEL") ?? "gpt-image-2.6-flare";
const QUALITY = Deno.env.get("BREED_IMAGE_QUALITY") ?? "low";
/** New pictures one account may ask for per day. Pictures that already exist are free. */
const DAILY_LIMIT = Number(Deno.env.get("BREED_DAILY_LIMIT") ?? "20");
/** Anonymous accounts are free to make, so they get fewer new pictures (linking Google or Kakao lifts it). */
const ANON_DAILY_LIMIT = Number(Deno.env.get("BREED_ANON_DAILY_LIMIT") ?? "5");
/** New pictures for all accounts together in a day, so many new accounts cannot run up the bill. */
const TOTAL_DAILY_LIMIT = Number(Deno.env.get("BREED_TOTAL_DAILY_LIMIT") ?? "300");
const BUCKET = "breeds";

// The user's breeding prompt, word for word. Image 1 = parent A, image 2 = parent B.
const PROMPT = `첨부한 두 캐릭터를 부모로 삼아, 스쿠카메라 세계관의 새로운 아기 캐릭터 한 마리를 만들어줘.

[유전 규칙]

* 첫 번째 이미지의 캐릭터를 부모 A, 두 번째 이미지의 캐릭터를 부모 B로 지정한다.
* 부모 A의 둥근 몸 형태와 전체 실루엣을 기본으로 유지한다.
* 부모 B의 대표 색상을 아기 캐릭터의 주된 몸 색상으로 적용한다. 원래 색을 얼룩처럼 남기지 말고 자연스럽고 일관된 색상으로 표현한다.
* 부모 B를 알아볼 수 있는 특징을 정확히 하나 골라 물려준다. 귀, 잎, 줄무늬, 고리, 꼬리, 껍질 무늬, 소재 중 부모 A의 형태와 가장 잘 어울리는 특징을 선택한다.
* 특징을 붙여 놓은 합성물처럼 만들지 말고, 처음부터 하나의 캐릭터로 태어난 것처럼 자연스럽게 통합한다.
* 얼굴은 부모 A의 원래 표정을 유지한다. 작은 갈색 점눈 두 개와 원래의 작고 순한 웃는 입을 그대로 따른다. 코나 부리가 있는 캐릭터는 그 얼굴 구조도 유지한다.
* 눈썹, 날카로운 눈매, 능글맞은 표정, 이빨, 과장된 볼살을 추가하지 않는다.

[그림체]
첨부 이미지와 동일한 포근한 캐릭터 그림체.
통통하고 동그란 몸, 짧고 작은 부속, 부드러운 파스텔 색상.
미세한 솜털과 펠트 같은 촉감, 은은한 입체감, 부드러운 확산광.
몸의 소재는 부모 A를 기준으로 유지하되, 물려받은 특징의 소재가 자연스럽게 어우러지게 한다.
실제 동물의 해부학보다 둥근 마스코트 비율을 우선한다.
작은 크기로 보아도 얼굴과 물려받은 특징이 명확하게 읽혀야 한다.

[구도와 출력]

* 아기 캐릭터 단 한 마리만 정면을 바라보게 한다.
* 전체 몸과 귀, 꼬리, 장식이 모두 보이게 한다.
* 정방형 캔버스 중앙에 배치하고 사방에 충분한 투명 여백을 둔다.
* 실제 알파 채널이 있는 투명 배경 PNG로 출력한다.
* 배경색, 체크무늬 배경, 바닥, 바닥 그림자, 글자, 이름, 테두리, 워터마크를 넣지 않는다.
* 부모 캐릭터, 비교 이미지, 여러 시안, 분할 화면을 함께 그리지 않는다.

최종 결과는 “부모 A의 형태 + 부모 B의 색상과 특징 하나 + 부모 A의 원래 순한 표정”을 가진, 사랑스럽고 완성도 있는 새로운 스쿠카메라 캐릭터여야 한다.`;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function decodeBase64(text: string): Uint8Array {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // who is asking (the gateway already checked the JWT; this reads the user from it)
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: userData } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (!user) return json({ error: "sign in first" }, 401);

  let body: { parentA?: string; parentB?: string; imageA?: string; imageB?: string };
  try { body = await req.json(); } catch { return json({ error: "bad json" }, 400); }
  const { parentA, parentB, imageA, imageB } = body;
  // species ids ("mori") and bred babies in bloom ("b_" + 12 hex, 재교배)
  const id = /^[a-z0-9_]{1,30}$/;
  if (!parentA || !parentB || !id.test(parentA) || !id.test(parentB) || parentA === parentB) {
    return json({ error: "two different parent ids" }, 400);
  }

  const path = `${parentA}-${parentB}.png`;
  const publicUrl = admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;

  // Already drawn for someone? Everyone shares it.
  const { data: found } = await admin.storage.from(BUCKET).list("", { search: path, limit: 1 });
  if (found?.some((file) => file.name === path)) return json({ url: publicUrl, cached: true });

  if (!imageA || !imageB || imageA.length > 4_000_000 || imageB.length > 4_000_000) {
    return json({ error: "parent images missing or too large" }, 400);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await admin.from("breed_generations").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).gte("created_at", since);
  if ((count ?? 0) >= (user.is_anonymous ? ANON_DAILY_LIMIT : DAILY_LIMIT)) return json({ error: "draw limit reached" }, 429);
  const { count: everyone } = await admin.from("breed_generations").select("id", { count: "exact", head: true })
    .gte("created_at", since);
  if ((everyone ?? 0) >= TOTAL_DAILY_LIMIT) return json({ error: "busy today" }, 429);

  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return json({ error: "OPENAI_API_KEY is not set" }, 500);

  const form = new FormData();
  form.append("model", MODEL);
  form.append("prompt", PROMPT);
  form.append("background", "transparent");
  form.append("output_format", "png");
  form.append("quality", QUALITY);
  form.append("size", "1024x1024");
  form.append("image[]", new Blob([decodeBase64(imageA)], { type: "image/png" }), "parent-a.png");
  form.append("image[]", new Blob([decodeBase64(imageB)], { type: "image/png" }), "parent-b.png");

  const answer = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST", headers: { Authorization: `Bearer ${key}` }, body: form,
  });
  if (!answer.ok) {
    const detail = (await answer.text()).slice(0, 300);
    console.error("openai", answer.status, detail);
    return json({ error: "image model failed", status: answer.status }, 502);
  }
  const result = await answer.json();
  const b64 = result?.data?.[0]?.b64_json;
  if (!b64) return json({ error: "no image returned" }, 502);

  const { error: uploadError } = await admin.storage.from(BUCKET)
    .upload(path, decodeBase64(b64), { contentType: "image/png", upsert: false });
  // Someone else may have finished the same pair a moment earlier; their picture is just as good.
  if (uploadError && !/exists|duplicate/i.test(uploadError.message)) {
    console.error("upload", uploadError.message);
    return json({ error: "could not store the picture" }, 500);
  }
  await admin.from("breed_generations").insert({ user_id: user.id, pair: `${parentA}-${parentB}` });
  return json({ url: publicUrl, cached: false });
});
