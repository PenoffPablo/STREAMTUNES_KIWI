import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

// El Access Token vive SOLO en el servidor (secret de la Edge Function).
// Configurarlo con:  supabase secrets set MP_ACCESS_TOKEN=APP_USR-...
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const supabase = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!MP_ACCESS_TOKEN) return json({ error: "MP_ACCESS_TOKEN no configurado" }, 500);

  let body: any;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "JSON inválido" }, 400);
  }

  const bandId = String(body?.band_id ?? "");
  const amount = Number(body?.amount);
  if (!UUID_RE.test(bandId) || !Number.isFinite(amount) || amount <= 0) {
    return json({ error: "band_id (uuid) y amount (> 0) son obligatorios" }, 400);
  }

  // La banda tiene que existir y estar aprobada: si no, Mercado Pago cobraría
  // un aporte que después la base (validate_donation) no deja registrar.
  // El nombre sale de la base, no del body (va en el título del cobro).
  const { data: band } = await supabase
    .from("bands")
    .select("name, status")
    .eq("id", bandId)
    .maybeSingle();
  if (!band || band.status !== "approved") {
    return json({ error: "La banda no existe o no está habilitada para recibir aportes" }, 404);
  }
  const bandName = String(band.name);

  // Id del intento de aporte que genera la app. Viaja como external_reference
  // SOLO para trazabilidad (buscar el pago en el panel de Mercado Pago). La
  // idempotencia del webhook NO depende de él: usa el id del pago de MP, que
  // no se puede falsificar.
  const donationId = String(body?.donation_id ?? "");
  if (!UUID_RE.test(donationId)) {
    return json({ error: "donation_id (uuid) es obligatorio" }, 400);
  }

  // Mismo tope que el trigger validate_donation: no cobrar algo que no se puede registrar.
  const { data: cfg } = await supabase.from("app_config").select("value").eq("key", "max_donation_ars").maybeSingle();
  const maxAmount = Number(cfg?.value ?? 5000);
  if (amount > maxAmount) {
    return json({ error: `El monto máximo por donación es $${maxAmount} ARS` }, 400);
  }

  // El donante sale del JWT de la sesión, NO del body: así nadie puede atribuir
  // una donación a otro usuario. Sin sesión, la donación queda sin donante.
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: authData } = jwt ? await supabase.auth.getUser(jwt) : { data: { user: null } };
  const donorId = authData?.user?.id ?? null;

  // external_reference tiene un máximo de 256 caracteres en Mercado Pago:
  // va solo el id. El resto viaja en `metadata`, que MP devuelve en el pago.
  const externalReference = donationId;
  const metadata = {
    donation_id: donationId,
    band_id: bandId,
    donor_id: donorId,
    message: typeof body?.message === "string" ? body.message.slice(0, 200) : null,
    is_anonymous: body?.is_anonymous === true,
  };

  const payload = {
    items: [
      {
        id: `donacion-${bandId}`,
        title: `Aporte a ${bandName} (StreamTunes)`,
        description: "Aporte directo a la banda independiente mediante StreamTunes",
        quantity: 1,
        currency_id: "ARS",
        unit_price: amount,
      },
    ],
    back_urls: {
      success: `https://streamtunes.app/band/${bandId}?status=success`,
      failure: `https://streamtunes.app/band/${bandId}?status=failure`,
      pending: `https://streamtunes.app/band/${bandId}?status=pending`,
    },
    auto_return: "approved",
    notification_url: `${SUPABASE_URL}/functions/v1/mercadopago-webhook`,
    external_reference: externalReference,
    metadata,
    statement_descriptor: "STREAMTUNES",
  };

  const mpRes = await fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!mpRes.ok) {
    return json({ error: "Mercado Pago rechazó la preferencia", detail: await mpRes.text() }, 502);
  }

  const data = await mpRes.json();
  return json({ init_point: data.init_point });
});
