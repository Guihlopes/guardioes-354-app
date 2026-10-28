import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyAuthenticationResponse } from "npm:@simplewebauthn/server@13.1.2";

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
    const body = await req.json();
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const host = new URL(req.headers.get("origin") || "https://guardioes-354-app.guardioesda354.workers.dev").hostname;
    const { data: challengeRow, error: challengeError } = await admin.from("passkey_challenges")
      .select("id,challenge").is("user_id", null).eq("purpose", "authentication")
      .gt("expires_at", new Date().toISOString()).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (challengeError || !challengeRow) return new Response(JSON.stringify({ error: "Solicitação expirada. Tente novamente." }), { status: 400, headers: cors });

    const credentialId = body.response?.id || body.response?.rawId;
    if (!credentialId) return new Response(JSON.stringify({ error: "Credencial inválida." }), { status: 400, headers: cors });
    const { data: credential, error: credentialError } = await admin.from("member_passkeys")
      .select("id,user_id,credential_id,public_key,counter,transports").eq("credential_id", credentialId).maybeSingle();
    if (credentialError || !credential) return new Response(JSON.stringify({ error: "Este aparelho ainda não foi cadastrado." }), { status: 404, headers: cors });

    const publicKeyBytes = Uint8Array.from(atob(credential.public_key), c => c.charCodeAt(0));
    const result = await verifyAuthenticationResponse({
      response: body.response,
      expectedChallenge: challengeRow.challenge,
      expectedOrigin: "https://" + host,
      expectedRPID: host,
      credential: {
        id: credential.credential_id,
        publicKey: publicKeyBytes,
        counter: Number(credential.counter),
        transports: credential.transports || [],
      },
      requireUserVerification: true,
    });
    await admin.from("passkey_challenges").delete().eq("id", challengeRow.id);
    if (!result.verified) return new Response(JSON.stringify({ error: "A autenticação não foi confirmada." }), { status: 401, headers: cors });
    const { error: updateError } = await admin.from("member_passkeys").update({
      counter: result.authenticationInfo.newCounter,
      last_used_at: new Date().toISOString(),
    }).eq("id", credential.id);
    if (updateError) throw updateError;
    const { data: userResult, error: userError } = await admin.auth.admin.getUserById(credential.user_id);
    if (userError || !userResult.user?.email) throw new Error("Não foi possível localizar a conta vinculada.");
    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: userResult.user.email,
    });
    if (linkError || !link.properties?.hashed_token) throw new Error("Não foi possível criar uma sessão segura.");
    return new Response(JSON.stringify({ verified: true, token_hash: link.properties.hashed_token, type: "magiclink" }), { status: 200, headers: cors });
  } catch (e) {
    console.error("passkey-auth-verify", e);
    return new Response(JSON.stringify({ error: "Falha ao validar o acesso rápido." }), { status: 500, headers: cors });
  }
});
