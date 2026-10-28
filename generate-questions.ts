// Supabase Edge Function: generate-questions. Handles the Studies AI button AND the Family Feud AI chat.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const FEUD = `You are Beacon's friendly game designer helping a host build a Family Feud style game with several survey rounds, for any kind of group. Ask ONE short question at a time to learn who is playing (age and kind of group), the theme or topic, how many rounds they want (1 to 10, default 3) and the difficulty. Ask at most 3 questions in total, then build the game immediately. Never ask the host to confirm. If the host says yes, ok, go or anything similar, build right away. Each round is a survey question in the style "Name something..." plus exactly 5 ranked answers of 1 to 3 words each, with points descending and adding up to about 100. Content must be suitable for all ages. Reply with JSON only: {"reply":"message to the host","ready":false} while asking, or {"reply":"one short sentence","ready":true,"rounds":[{"question":"...","answers":[{"text":"...","points":38}]}]} when done, with one entry per round.`;
const QUIZ = `You write quiz questions for live group quiz sessions. Reply with JSON only: {"questions":[{"kind":"multiple_choice","prompt":"...","options":["A","B","C","D"],"correct_index":0,"time_limit_seconds":20,"points":1000}]}. multiple_choice has exactly 4 options and one correct_index. true_false has options ["True","False"]. poll has 2 to 4 options and no right answer (use correct_index 0). Use only the kinds requested. Questions must be clear, fair and suitable for all ages.`;
const QUIZCHAT = `You are Beacon's friendly quiz designer helping a host build questions for a live group quiz, for any kind of group. Ask ONE short question at a time to learn who is playing (age and kind of group), the topic or passage, how many questions they want (default 5) and the difficulty. Ask at most 3 questions in total, then build the questions immediately. Never ask the host to confirm. If the host says yes, ok, go or anything similar, build right away. Questions must be clear, fair and suitable for all ages. Reply with JSON only: {"reply":"message to the host","ready":false} while asking, or {"reply":"one short sentence","ready":true,"questions":[{"kind":"multiple_choice","prompt":"...","options":["A","B","C","D"],"correct_index":0,"time_limit_seconds":20,"points":1000}]} when done. multiple_choice has exactly 4 options; true_false has options ["True","False"]; poll has 2 to 4 options and correct_index 0.`;
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: host } = await sb.rpc("is_host");
    if (!host) return J({ error: "host_only" }, 403);
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return J({ error: "no_key" }, 500);
    const b = await req.json();
    let system = QUIZ, contents;
    if ((b.mode === "feud_chat" || b.mode === "quiz_chat") && Array.isArray(b.messages)) {
      system = b.mode === "quiz_chat" ? QUIZCHAT : FEUD;
      contents = b.messages.slice(-14).map((m: any) => ({ role: m.role === "user" ? "user" : "model", parts: [{ text: String(m.text).slice(0, 1500) }] }));
    } else {
      const count = Math.min(20, Math.max(1, +b.count || 5)), kinds = Array.isArray(b.kinds) ? b.kinds.join(", ") : "multiple_choice";
      contents = [{ role: "user", parts: [{ text: `Topic: ${String(b.topic ?? "").slice(0, 300)}\nPassage or notes: ${String(b.passage ?? "").slice(0, 6000)}\nNumber of questions: ${count}\nKinds allowed: ${kinds}` }] }];
    }
    const model = Deno.env.get("GEMINI_MODEL") || "gemini-2.5-flash";
    const call = () => fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({ systemInstruction: { parts: [{ text: system }] }, contents, generationConfig: { responseMimeType: "application/json", temperature: 0.8 } }),
    });
    let r = await call();
    for (let i = 0; i < 2 && [429, 500, 503].includes(r.status); i++) { await new Promise((z) => setTimeout(z, 1500)); r = await call(); }
    if (!r.ok) return J({ error: "ai_failed", status: r.status }, 502);
    const text = (await r.json()).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    try { return J(JSON.parse(text)); } catch (_) { return J({ reply: text, ready: false }); }
  } catch (_e) { return J({ error: "server" }, 500); }
});
