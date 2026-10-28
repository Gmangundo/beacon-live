// Supabase Edge Function: jaas-token. Gives joined players (and the host) a signed pass to their game's call room.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createSign } from "node:crypto";
import { Buffer } from "node:buffer";
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: u } = await sb.auth.getUser();
    const uid = u?.user?.id;
    if (!uid) return J({ error: "auth" }, 401);
    const { game } = await req.json();
    if (typeof game !== "string" || !/^[0-9a-f-]{36}$/i.test(game)) return J({ error: "bad_game" }, 400);
    const { data: g } = await sb.from("feud_games").select("id,active").eq("id", game).maybeSingle();
    if (!g || !g.active) return J({ error: "no_game" }, 404);
    const { data: host } = await sb.rpc("is_host");
    let name = "Host";
    const mod = host === true;
    if (!mod) {
      const { data: p } = await sb.from("feud_players").select("nickname,emoji").eq("game_id", game).eq("user_id", uid).maybeSingle();
      if (!p) return J({ error: "not_player" }, 403);
      name = `${p.emoji} ${p.nickname}`;
    }
    const appId = Deno.env.get("JAAS_APP_ID"), kid = Deno.env.get("JAAS_KEY_ID");
    const pem = (Deno.env.get("JAAS_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n").trim();
    if (!appId || !kid || !pem) return J({ error: "no_jaas" }, 500);
    const room = "beacon" + game.replace(/-/g, "");
    const now = Math.floor(Date.now() / 1000);
    const head = b64({ alg: "RS256", kid, typ: "JWT" });
    const body = b64({ aud: "jitsi", iss: "chat", iat: now, nbf: now - 10, exp: now + 10800, sub: appId, room,
      context: { user: { id: uid, name, avatar: "", email: "", moderator: mod ? "true" : "false" },
        features: { livestreaming: "false", recording: "false", transcription: "false", "outbound-call": "false" } } });
    const sig = createSign("RSA-SHA256").update(`${head}.${body}`).sign(pem).toString("base64url");
    return J({ jwt: `${head}.${body}.${sig}`, room, appId });
  } catch (_e) { return J({ error: "server" }, 500); }
});
