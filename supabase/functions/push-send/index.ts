import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY")!;
const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY")!;
const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET")!;
const db = createClient(supabaseUrl, serviceRoleKey);

webpush.setVapidDetails("mailto:push@guardioesda354.com.br", vapidPublicKey, vapidPrivateKey);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!webhookSecret || req.headers.get("x-push-webhook-secret") !== webhookSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const payload = await req.json();
    const record = payload.record ?? payload;
    const recipientId = record.recipient_id;
    if (!recipientId) return Response.json({ skipped: true, reason: "No recipient_id" });

    const { data: subscriptions, error } = await db
      .from("push_subscriptions").select("id, endpoint, subscription").eq("user_id", recipientId);
    if (error) throw error;

    const page = record.source_type === "vote" ? "votes" : "agenda";
    const message = JSON.stringify({
      title: record.title || "Guardiões da 354",
      body: record.body || "Você tem uma nova atualização no aplicativo.",
      url: "/?pushPage=" + page,
      page,
      source_id: record.source_id || null,
      tag: "guardioes-" + (record.source_type || "update") + "-" + (record.source_id || record.id || Date.now())
    });
    const results = await Promise.all((subscriptions || []).map(async (item) => {
      try {
        await webpush.sendNotification(item.subscription, message, { TTL: 86400 });
        return { sent: true };
      } catch (err) {
        const status = Number((err as { statusCode?: number }).statusCode || 0);
        if (status === 404 || status === 410) await db.from("push_subscriptions").delete().eq("id", item.id);
        console.error("Push delivery failed:", status, err);
        return { sent: false, status };
      }
    }));
    return Response.json({ ok: true, subscriptions: subscriptions?.length || 0, results });
  } catch (err) {
    console.error("push-send failed:", err);
    return Response.json({ error: String(err) }, { status: 500 });
  }
});
