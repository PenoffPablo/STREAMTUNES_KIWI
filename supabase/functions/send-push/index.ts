// Edge Function: envía notificaciones push con Firebase Cloud Messaging (API HTTP v1).
//
// Se dispara con Database Webhooks de Supabase (Dashboard > Database > Webhooks):
//   * INSERT en public.songs      -> avisa a los SEGUIDORES de la banda ("nuevo tema")
//   * INSERT en public.donations  -> avisa a los MIEMBROS de la banda ("recibiste un aporte")
//
// Secrets necesarios (supabase secrets set ...):
//   FIREBASE_SERVICE_ACCOUNT  JSON completo de la cuenta de servicio de Firebase
//   PUSH_WEBHOOK_SECRET       valor que el webhook manda en el header x-webhook-secret
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);
const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
type Push = { title: string; body: string; bandId: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ---------- OAuth2 para FCM: JWT firmado RS256 con la cuenta de servicio ----------
function base64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`OAuth FCM falló: ${await res.text()}`);
  return (await res.json()).access_token;
}

// ---------- Destinatarios ----------
async function tokensForUsers(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const { data, error } = await supabase.from("device_tokens").select("token").in("user_id", userIds);
  if (error) throw error;
  return (data ?? []).map((r) => r.token as string);
}

async function bandName(bandId: string): Promise<string> {
  const { data } = await supabase.from("bands").select("name").eq("id", bandId).maybeSingle();
  return (data?.name as string) ?? "Una banda que seguís";
}

async function buildPush(table: string, record: Record<string, unknown>): Promise<{ push: Push; userIds: string[] } | null> {
  const bandId = String(record.band_id ?? "");
  if (!bandId) return null;

  if (table === "songs") {
    if (record.hidden === true) return null;
    const { data } = await supabase.from("band_follows").select("user_id").eq("band_id", bandId);
    return {
      userIds: (data ?? []).map((r) => r.user_id as string),
      push: { title: `🎸 Nuevo tema de ${await bandName(bandId)}`, body: String(record.title ?? "Escuchalo ahora"), bandId },
    };
  }

  if (table === "donations") {
    if (record.status && record.status !== "approved") return null;
    const { data } = await supabase.from("band_members").select("user_id").eq("band_id", bandId);
    // El esquema histórico usa `amount_ars`; la base actual, `amount`.
    const amount = Number(record.amount ?? record.amount_ars ?? 0);
    return {
      userIds: (data ?? []).map((r) => r.user_id as string),
      push: { title: "💸 ¡Recibiste un aporte!", body: `Un fan aportó $${amount.toFixed(0)} ARS a la banda.`, bandId },
    };
  }
  return null;
}

// ---------- Envío ----------
async function sendToToken(sa: ServiceAccount, accessToken: string, token: string, push: Push) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: push.title, body: push.body },
        data: { band_id: push.bandId }, // la app lo usa para abrir el perfil
        android: { priority: "HIGH" },
      },
    }),
  });
  if (res.ok) return "sent";
  const text = await res.text();
  // Token vencido o desinstalado: se limpia de la tabla.
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    await supabase.from("device_tokens").delete().eq("token", token);
    return "removed";
  }
  console.error("FCM error", res.status, text);
  return "failed";
}

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!WEBHOOK_SECRET || req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = await req.json();
    if (payload?.type !== "INSERT" || !payload?.record) return json({ skipped: "not an insert" });

    const target = await buildPush(String(payload.table), payload.record);
    if (!target) return json({ skipped: "nothing to notify" });

    const tokens = await tokensForUsers(target.userIds);
    if (tokens.length === 0) return json({ sent: 0 });

    const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}") as ServiceAccount;
    const accessToken = await getAccessToken(sa);
    const results = await Promise.all(tokens.map((t) => sendToToken(sa, accessToken, t, target.push)));
    return json({
      sent: results.filter((r) => r === "sent").length,
      removed: results.filter((r) => r === "removed").length,
      failed: results.filter((r) => r === "failed").length,
    });
  } catch (err) {
    console.error(err);
    return json({ error: (err as Error).message }, 500);
  }
});
