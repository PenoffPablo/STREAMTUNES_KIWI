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

/**
 * Pago que MP aprobó pero que no se puede registrar como aporte (banda
 * suspendida, monto mayor al tope, pago sin banda). La plata ya está en la
 * cuenta de KIWI: se guarda en `rejected_payments` para que un moderador la
 * vea en su panel y la devuelva. Idempotente por `mp_payment_id`.
 */
async function recordRejected(
  mpPaymentId: string,
  amount: number,
  reason: string,
  bandId: string | null,
  donorId: string | null,
) {
  const { error } = await supabase.from("rejected_payments").upsert(
    { mp_payment_id: mpPaymentId, amount, reason, band_id: bandId, donor_id: donorId },
    { onConflict: "mp_payment_id", ignoreDuplicates: true },
  );
  if (error) {
    // Si la banda o el donante ya no existen, se guarda sin esas referencias.
    if (error.code === "23503") {
      const retry = await supabase.from("rejected_payments").upsert(
        { mp_payment_id: mpPaymentId, amount, reason, band_id: null, donor_id: null },
        { onConflict: "mp_payment_id", ignoreDuplicates: true },
      );
      if (retry.error) throw retry.error;
      return;
    }
    throw error;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // Sin token no se puede verificar NINGÚN pago: 500 para que MP reintente
  // cuando el secret esté configurado (con 200 los pagos se perderían).
  if (!MP_ACCESS_TOKEN) {
    console.error("Falta el secret MP_ACCESS_TOKEN");
    return json({ error: "Webhook sin configurar" }, 500);
  }
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
    if (!mpRes.ok) {
      // 404: la notificación no es de un pago real (p. ej. pruebas): no hay
      // nada que registrar. Cualquier otro error (500, 429, 401) es pasajero
      // o de configuración: 500 para que Mercado Pago REINTENTE y el pago no
      // se pierda.
      if (mpRes.status === 404) return json({ skipped: "payment not found" });
      console.error("Mercado Pago respondió", mpRes.status, "al consultar el pago", paymentId);
      return json({ error: "No se pudo consultar el pago en Mercado Pago" }, 500);
    }
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
    const donorId = (meta.donor_id as string | null) ?? null;
    const amount = Number(payment.transaction_amount);
    if (!bandId) {
      await recordRejected(mpPaymentId, amount, "El pago no indica a qué banda va.", null, donorId);
      return json({ status: "rejected", payment_id: mpPaymentId, reason: "sin band_id" });
    }

    // Sin `id`: lo genera la base. Así ningún dato que venga de afuera puede
    // apuntar a una fila existente.
    const row = {
      band_id: bandId,
      donor_id: donorId,
      amount,
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
      // reintentar no lo arregla. Se guarda como "pago a devolver" (visible
      // en el panel de moderación) y se responde 200 para que MP no reintente.
      if (error.code === "P0001") {
        console.error("Pago aprobado que la base rechazó", mpPaymentId, error.message);
        await recordRejected(mpPaymentId, amount, error.message, bandId, donorId);
        return json({ status: "rejected", payment_id: mpPaymentId, reason: error.message });
      }
      // Banda o donante inexistentes / id con formato inválido: tampoco se
      // arregla reintentando.
      if (error.code === "23503" || error.code === "22P02") {
        console.error("Pago aprobado con datos inválidos", mpPaymentId, error.message);
        await recordRejected(mpPaymentId, amount, "La banda o el donante del pago no existen.", null, null);
        return json({ status: "rejected", payment_id: mpPaymentId, reason: error.code });
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
