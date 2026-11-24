import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

// Webhook de Mercado Pago. KIWI cobra todos los aportes en su cuenta, y esta
// función es la ÚNICA que escribe en `donations` (service role).
//
// * Pago APROBADO  -> se registra la donación.
// * Pago DEVUELTO / CONTRACARGO / CANCELADO (que ya estaba aprobado)
//                  -> la donación pasa a `refunded`: deja de contar para el
//                     total de la banda y para lo que KIWI le debe.
//
// Idempotencia: la clave es el id del PAGO verificado contra la API de MP
// (`mp_payment_id`), que nadie puede inventar. Un pago = una fila; los
// reintentos de Mercado Pago se ignoran. (Antes se usaba un id que mandaba la
// app, y un pago podía pisar a otro.)
//
// El total de la banda (bands.donations_collected) lo mantiene el trigger
// `donations_accumulate`: suma al aprobarse y resta al pasar a refunded.
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

/** Estados de MP que anulan un pago que ya había sido aprobado. */
const REVERSED = new Set(["refunded", "charged_back", "cancelled"]);

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
    const mpPaymentId = String(payment.id ?? paymentId);

    // 2. Devoluciones: si el pago estaba aprobado, se anula la donación.
    if (REVERSED.has(payment.status)) {
      const { data, error } = await supabase
        .from("donations")
        .update({ status: "refunded" })
        .eq("mp_payment_id", mpPaymentId)
        .eq("status", "approved")
        .select("id");
      if (error) throw error;
      return json({ status: "reversed", payment_id: mpPaymentId, updated: data?.length ?? 0 });
    }
    if (payment.status !== "approved") return json({ payment_status: payment.status });

    // 3. Datos del aporte: `metadata` (la arma create-preference en el servidor).
    //    Para pagos de preferencias viejas se intenta el JSON del external_reference.
    let meta: Record<string, unknown> = payment.metadata ?? {};
    if (!meta.band_id && payment.external_reference) {
      try {
        meta = JSON.parse(payment.external_reference);
      } catch (_) {
        // external_reference nuevo: no es JSON
      }
    }
    const bandId = String(meta.band_id ?? "");
    if (!bandId) return json({ error: "Pago sin band_id en metadata" });

    // Sin `id`: lo genera la base. Así ningún dato que venga de afuera puede
    // apuntar a una fila existente.
    const row = {
      band_id: bandId,
      donor_id: (meta.donor_id as string | null) ?? null,
      amount: Number(payment.transaction_amount),
      // Lo que efectivamente entra a la cuenta de KIWI (descontada la comisión
      // de MP). Es la base de lo que después se le liquida a la banda.
      net_amount: Number(payment.transaction_details?.net_received_amount ?? payment.transaction_amount),
      // Prueba de que el pago fue verificado contra la API de Mercado Pago.
      mp_payment_id: mpPaymentId,
      currency: "ARS",
      message: (meta.message as string | null) ?? null,
      is_public: meta.is_anonymous !== true,
      status: "approved",
    };

    // 4. INSERT ... ON CONFLICT (mp_payment_id) DO NOTHING: idempotente.
    const { error } = await supabase
      .from("donations")
      .upsert(row, { onConflict: "mp_payment_id", ignoreDuplicates: true });
    if (error) {
      // Rechazo de negocio de la base (banda no aprobada, monto > tope):
      // reintentar no lo arregla. Se registra y se responde 200 para que
      // Mercado Pago no reintente en loop.
      if (error.code === "P0001") {
        console.error("Pago aprobado que la base rechazó", mpPaymentId, error.message);
        return json({ status: "rejected", payment_id: mpPaymentId, reason: error.message });
      }
      throw error;
    }

    return json({ status: "success", payment_id: mpPaymentId });
  } catch (err) {
    console.error(err);
    // 500 para que Mercado Pago reintente más tarde.
    return json({ error: (err as Error).message }, 500);
  }
});
