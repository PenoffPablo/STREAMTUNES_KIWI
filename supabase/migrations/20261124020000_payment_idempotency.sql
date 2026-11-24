-- ----------------------------------------------------------------------
-- Idempotencia de pagos por el id de Mercado Pago
--
-- Antes, el webhook usaba como clave el `donation_id` que generaba la app:
--   * pagar dos veces desde el mismo modal hacía que el 2.º pago PISARA al 1.º;
--   * como los ids de las donaciones son públicos, alguien podía pagar $1 con
--     el id de una donación ajena y sobrescribirla (monto, banda, donante),
--     corrompiendo los saldos a liquidar.
-- Ahora la clave es el id del PAGO verificado contra la API de Mercado Pago,
-- que nadie puede inventar: un pago = una fila, y los reintentos se ignoran.
-- ----------------------------------------------------------------------

-- PostgREST (upsert ... on_conflict) no puede usar un índice PARCIAL como
-- destino del conflicto: se reemplaza por una constraint UNIQUE completa.
-- Los NULL (donaciones viejas sin verificar) no chocan entre sí.
drop index if exists public.donations_mp_payment_id_key;

alter table public.donations
  drop constraint if exists donations_mp_payment_id_key;
alter table public.donations
  add constraint donations_mp_payment_id_key unique (mp_payment_id);
