import { createClient } from "npm:@supabase/supabase-js@2";
import * as webpush from "jsr:@negrel/webpush";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey || req.headers.get("Authorization") !== `Bearer ${serviceKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const payload = await req.json();
    if (payload.type !== "INSERT" || payload.table !== "club_notifications" || !payload.record?.recipient_id) {
      return Response.json({ ignored: true });
    }
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: devices, error } = await supabase
      .from("club_push_subscriptions")
      .select("id,subscription")
      .eq("user_id", payload.record.recipient_id);
    if (error) throw error;
    if (!devices?.length) return Response.json({ sent: 0, reason: "No subscribed devices" });

    const jwkText = Deno.env.get("VAPID_KEYS_JSON");
    if (!jwkText) throw new Error("VAPID_KEYS_JSON secret is missing");
    const vapidKeys = await webpush.importVapidKeys(JSON.parse(jwkText), { extractable: false });
    const appServer = await webpush.ApplicationServer.new({
      contactInformation: "mailto:admin@guardioes354.com.br",
      vapidKeys,
    });
    const sourceType = payload.record.source_type;
    const message = JSON.stringify({
      title: payload.record.title || "Guardiões da 354",
      body: payload.record.body || "Você tem uma nova atualização do motoclube.",
      url: "/",
      page: sourceType === "vote" ? "votes" : "agenda",
      source_id: payload.record.source_id,
      tag: `guardioes-${sourceType || "aviso"}-${payload.record.source_id || payload.record.id}`,
    });

    let sent = 0;
    const failed: string[] = [];
    await Promise.all(devices.map(async (device: { id: number; subscription: unknown }) => {
      try {
        const subscriber = appServer.subscribe(device.subscription as never);
        await subscriber.pushTextMessage(message, {});
        sent++;
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        failed.push(detail);
        if (/404|410|gone|not found/i.test(detail)) {
          await supabase.from("club_push_subscriptions").delete().eq("id", device.id);
        }
      }
    }));
    return Response.json({ sent, failed: failed.length, details: failed.slice(0, 3) });
  } catch (err) {
    console.error("send-web-push failed", err);
    return Response.json({ error: err instanceof Error ? err.message : String(err) }, { status: 500 });
  }
});
