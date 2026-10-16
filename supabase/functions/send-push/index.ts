import webpush from "npm:web-push@3.6.7";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const row = payload.record ?? payload;
    if (!row?.recipient_id || !row?.title) {
      return new Response(JSON.stringify({ skipped: true, reason: "Missing recipient or title" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const publicKey = Deno.env.get("VAPID_PUBLIC_KEY")!;
    const privateKey = Deno.env.get("VAPID_PRIVATE_KEY")!;
    webpush.setVapidDetails("mailto:admin@guardioes354.app", publicKey, privateKey);

    const db = createClient(supabaseUrl, serviceRoleKey);
    const { data: devices, error } = await db
      .from("push_subscriptions")
      .select("id, endpoint, subscription")
      .eq("user_id", row.recipient_id);

    if (error) throw error;
    if (!devices?.length) {
      return new Response(JSON.stringify({ sent: 0, reason: "Recipient has no subscribed devices" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = "https://guardioes-354-app.guardioesda354.workers.dev/";
    const message = JSON.stringify({
      title: row.title,
      body: row.body || "Você tem uma nova notificação do motoclube.",
      source_type: row.source_type || "",
      source_id: row.source_id || "",
      page: row.source_type === "vote" ? "votes" : "agenda",
      url,
      tag: "club-notification-" + row.id,
    });

    let sent = 0;
    const errors: string[] = [];
    await Promise.all(devices.map(async (device: any) => {
      try {
        await webpush.sendNotification(device.subscription, message, { TTL: 60 * 60 * 24 });
        sent++;
      } catch (err: any) {
        const status = err?.statusCode;
        if (status === 404 || status === 410) {
          await db.from("push_subscriptions").delete().eq("id", device.id);
        } else {
          errors.push(String(err?.message || err));
        }
      }
    }));

    return new Response(JSON.stringify({ sent, errors }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("send-push error:", err);
    return new Response(JSON.stringify({ error: String((err as Error)?.message || err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
