import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

// Webhook de Mercado Pago: registra en `donations` los pagos APROBADOS.
//
// Es IDEMPOTENTE: el id de la fila es el `donation_id` que generó la app.
//   * Mercado Pago reintenta notificaciones -> la misma fila, no duplicados.
//   * Si el fan además tocó "Ya transferí" -> la misma fila, no duplicados.
// El total de la banda (bands.donations_collected) lo actualiza el trigger
// `donations_accumulate` de la base: acá NO se suma a mano (antes se sumaba
// dos veces: una el trigger y otra esta función).
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  try {
    const url = new URL(req.url);
    let paymentId = url.searchParams.get("data.id") || url.searchParams.get("id");
    if (!paymentId && req.method === "POST") {
      try {
        const body = await req.json();
        if (body?.type && body.type !== "payment") return json({ skipped: body.type });
        paymentId = body?.data?.id || body?.id;
      } catch (_) {
        // cuerpo vacío o no JSON
      }
    }
    if (!paymentId) return json({ message: "No payment id received" });
    // Se pega en una URL llamada con el token del servidor: solo dígitos.
    if (!/^\d+$/.test(String(paymentId))) return json({ error: "payment id inválido" }, 400);

    // 1. Estado REAL del pago (no se confía en el cuerpo de la notificación).
    const mpRes = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    });
    if (!mpRes.ok) return json({ error: "Failed to fetch payment from MP" });
    const payment = await mpRes.json();
    if (payment.status !== "approved") return json({ payment_status: payment.status });

    // 2. Datos de la donación: `metadata` (preferencias nuevas). Para pagos de
    //    preferencias viejas se intenta leer el JSON del external_reference.
    let meta: Record<string, unknown> = payment.metadata ?? {};
    if (!meta.band_id && payment.external_reference) {
      try {
        meta = JSON.parse(payment.external_reference);
      } catch (_) {
        // external_reference nuevo: es solo el donation_id
      }
    }
    const bandId = String(meta.band_id ?? "");
    if (!bandId) return json({ error: "Pago sin band_id en metadata" });

    const candidateId = String(meta.donation_id ?? payment.external_reference ?? "");
    const row = {
      ...(UUID_RE.test(candidateId) ? { id: candidateId } : {}),
      band_id: bandId,
      donor_id: (meta.donor_id as string | null) ?? null,
      amount: Number(payment.transaction_amount),
      // Lo que efectivamente entra a la cuenta de KIWI (descontada la comisión
      // de MP). Es la base de lo que después se le liquida a la banda.
      net_amount: Number(payment.transaction_details?.net_received_amount ?? payment.transaction_amount),
      // Prueba de que el pago fue verificado contra la API de Mercado Pago.
      mp_payment_id: String(payment.id ?? paymentId),
      currency: "ARS",
      message: (meta.message as string | null) ?? null,
      is_public: meta.is_anonymous !== true,
      status: "approved",
    };

    // 3. Upsert por id con los datos REALES del pago:
    //    * el id es el que generó la app, así un mismo pago es siempre la misma fila;
    //    * si Mercado Pago reintenta, la fila ya está aprobada y el trigger no
    //      vuelve a sumar (solo suma al pasar a approved).
    const { error } = await supabase
      .from("donations")
      .upsert(row, { onConflict: "id" });
    if (error) {
      // Rechazo de negocio de la base (banda no aprobada, monto > tope):
      // reintentar no lo arregla. Se registra y se responde 200 para que
      // Mercado Pago no reintente en loop.
      if (error.code === "P0001") {
        console.error("Pago aprobado que la base rechazó", paymentId, error.message);
        return json({ status: "rejected", payment_id: paymentId, reason: error.message });
      }
      throw error;
    }

    return json({ status: "success", payment_id: paymentId, donation_id: row.id ?? null });
  } catch (err) {
    console.error(err);
    // 500 para que Mercado Pago reintente más tarde.
    return json({ error: (err as Error).message }, 500);
  }
});
