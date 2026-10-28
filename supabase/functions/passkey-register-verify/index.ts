import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyRegistrationResponse } from "npm:@simplewebauthn/server@13.1.2";

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
    const client = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error } = await client.auth.getUser();
    if (error || !user) return new Response(JSON.stringify({ error: "Autenticação necessária." }), { status: 401, headers: cors });

    const body = await req.json();
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: challengeRow, error: challengeError } = await admin.from("passkey_challenges")
      .select("id,challenge").eq("user_id", user.id).eq("purpose", "registration")
      .gt("expires_at", new Date().toISOString()).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (challengeError || !challengeRow) return new Response(JSON.stringify({ error: "Solicitação expirada. Tente novamente." }), { status: 400, headers: cors });

    const host = new URL(req.headers.get("origin") || "https://guardioes-354-app.guardioesda354.workers.dev").hostname;
    const result = await verifyRegistrationResponse({
      response: body.response,
      expectedChallenge: challengeRow.challenge,
      expectedOrigin: "https://" + host,
      expectedRPID: host,
      requireUserVerification: true,
    });
    await admin.from("passkey_challenges").delete().eq("id", challengeRow.id);
    if (!result.verified || !result.registrationInfo) return new Response(JSON.stringify({ error: "Não foi possível validar o acesso deste aparelho." }), { status: 400, headers: cors });

    const info = result.registrationInfo;
    const { error: saveError } = await admin.from("member_passkeys").insert({
      user_id: user.id,
      credential_id: info.credential.id,
      public_key: btoa(String.fromCharCode(...info.credential.publicKey)),
      counter: info.credential.counter,
      transports: body.response?.response?.transports || [],
      device_name: typeof body.deviceName === "string" ? body.deviceName.slice(0, 80) : "Meu aparelho",
    });
    if (saveError) throw saveError;
    return new Response(JSON.stringify({ verified: true }), { status: 200, headers: cors });
  } catch (e) {
    console.error("passkey-register-verify", e);
    return new Response(JSON.stringify({ error: "Falha ao confirmar o cadastro. Tente novamente." }), { status: 500, headers: cors });
  }
});
