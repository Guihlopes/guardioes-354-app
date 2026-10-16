import { createClient } from "npm:@supabase/supabase-js@2";
import * as webpush from "jsr:@negrel/webpush";

const corsHeaders = { "Content-Type": "application/json" };

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!expected || req.headers.get("Authorization") !== `Bearer ${expected}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const payload = await req.json();
    if (payload.type !== "INSERT" || payload.table !== "club_notifications" || !payload.record?.recipient_id) {
      return Response.json({ ignored: true });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
    const { data: devices, error } = await supabase
      .from("club_push_subscriptions")
      .select("id,endpoint,subscription")
      .eq("user_id", payload.record.recipient_id);

    if (error) throw error;
    if (!devices?.length) return Response.json({ sent: 0, reason: "No subscribed devices" });

    const jwkText = Deno.env.get("VAPID_KEYS_JSON");
    if (!jwkText) throw new Error("VAPID_KEYS_JSON secret is missing");
    const vapidKeys = await webpush.importVapidKeys(JSON.parse(jwkText), { extractable: false });
    const appServer = await webpush.ApplicationServer.new({
      contactInformation: "mailto:guardiões354@example.com",
      vapidKeys,
    });

    const sourceType = payload.record.source_type;
    const page = sourceType === "vote" ? "votes" : "agenda";
    const message = JSON.stringify({
      title: payload.record.title || "Guardiões da 354",
      body: payload.record.body || "Você tem uma nova atualização do motoclube.",
      url: "/",
      page,
      source_id: payload.record.source_id,
      tag: `guardioes-${payload.record.source_type || "notice"}-${payload.record.source_id || payload.record.id}`,
    });

    let sent = 0;
    const failures: string[] = [];
    await Promise.all(devices.map(async (device: { id: number; endpoint: string; subscription: webpush.PushSubscription }) => {
      try {
        const subscriber = appServer.subscribe(device.subscription);
        await subscriber.pushTextMessage(message, {});
        sent++;
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        failures.push(detail);
        if (/404|410|gone|not found/i.test(detail)) {
          await supabase.from("club_push_subscriptions").delete().eq("id", device.id);
        }
      }
    }));

    return Response.json({ sent, failed: failures.length, failures: failures.slice(0, 5) });
  } catch (error) {
    console.error("send-web-push error", error);
    return Response.json({ error: error instanceof Error ? error.message : String(error) }, { status: 500, headers: corsHeaders });
  }
});
