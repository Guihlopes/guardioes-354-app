import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generateRegistrationOptions } from "npm:@simplewebauthn/server@13.1.2";

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
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const auth = req.headers.get("Authorization") || "";
    const supabase = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return new Response(JSON.stringify({ error: "Autenticação necessária." }), { status: 401, headers: cors });

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: existing, error: readError } = await admin.from("member_passkeys")
      .select("credential_id").eq("user_id", user.id);
    if (readError) throw readError;

    const rpName = "Guardiões da 354";
    const host = new URL(req.headers.get("origin") || "https://guardioes-354-app.guardioesda354.workers.dev").hostname;
    const options = await generateRegistrationOptions({
      rpName,
      rpID: host,
      userName: user.email || user.id,
      userID: new TextEncoder().encode(user.id),
      attestationType: "none",
      excludeCredentials: (existing || []).map((c) => ({ id: c.credential_id })),
      authenticatorSelection: { residentKey: "preferred", userVerification: "required" },
      timeout: 60000,
    });

    const { error: insertError } = await admin.from("passkey_challenges").insert({
      user_id: user.id, challenge: options.challenge, purpose: "registration",
      expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
    });
    if (insertError) throw insertError;
    return new Response(JSON.stringify(options), { status: 200, headers: cors });
  } catch (e) {
    console.error("passkey-register-options", e);
    return new Response(JSON.stringify({ error: "Não foi possível iniciar o cadastro de acesso rápido." }), { status: 500, headers: cors });
  }
});
