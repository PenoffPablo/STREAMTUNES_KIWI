import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

// Credenciales para verificación oficial de pagos de Mercado Pago
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://fajwcwabcdxetuffoiuh.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  // Responder preflight de CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  try {
    const url = new URL(req.url);
    let paymentId = url.searchParams.get("data.id") || url.searchParams.get("id");

    if (!paymentId && req.method === "POST") {
      try {
        const body = await req.json();
        paymentId = body?.data?.id || body?.id;
      } catch (_) {}
    }

    if (!paymentId) {
      return new Response(JSON.stringify({ message: "No payment id received" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. Consultar el estado real del pago en la API de Mercado Pago
    const mpRes = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    });

    if (!mpRes.ok) {
      return new Response(JSON.stringify({ error: "Failed to fetch payment from MP" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payment = await mpRes.json();

    // 2. Si el pago fue aprobado, registrar en PostgreSQL
    if (payment.status === "approved") {
      const extRef = payment.external_reference;
      let meta: any = {};
      if (extRef) {
        try {
          meta = JSON.parse(extRef);
        } catch (_) {}
      }

      const bandId = meta.band_id;
      const amount = payment.transaction_amount;
      const donorName = meta.is_anonymous ? "Fan anónimo" : (meta.donor_name || "Fan de la banda");
      const donorUserId = meta.donor_user_id || null;
      const message = meta.message || null;
      const isPublic = !meta.is_anonymous;

      if (bandId) {
        // Insertar donación en la base de datos
        await supabase.from("donations").insert({
          band_id: bandId,
          donor_id: donorUserId,
          amount: amount,
          currency: "ARS",
          message: message,
          is_public: isPublic,
          status: "approved",
        });

        // Actualizar acumulador en la tabla bands
        const { data: bandData } = await supabase
          .from("bands")
          .select("donations_collected")
          .eq("id", bandId)
          .single();

        const currentTotal = Number(bandData?.donations_collected || 0);
        await supabase
          .from("bands")
          .update({ donations_collected: currentTotal + amount })
          .eq("id", bandId);
      }
    }

    return new Response(
      JSON.stringify({
        status: "success",
        payment_id: paymentId,
        payment_status: payment.status,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});

