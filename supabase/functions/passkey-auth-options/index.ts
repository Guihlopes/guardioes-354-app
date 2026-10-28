import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generateAuthenticationOptions } from "npm:@simplewebauthn/server@13.1.2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const host = new URL(req.headers.get("origin") || "https://guardioes-354-app.guardioesda354.workers.dev").hostname;
    const options = await generateAuthenticationOptions({
      rpID: host,
      userVerification: "required",
      timeout: 60000,
    });
    const { error } = await admin.from("passkey_challenges").insert({
      user_id: null, challenge: options.challenge, purpose: "authentication",
      expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
    });
    if (error) throw error;
    return new Response(JSON.stringify(options), { status: 200, headers: cors });
  } catch (e) {
    console.error("passkey-auth-options", e);
    return new Response(JSON.stringify({ error: "Não foi possível iniciar a autenticação." }), { status: 500, headers: cors });
  }
});
