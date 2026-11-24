-- ----------------------------------------------------------------------
-- KIWI cobra todos los aportes y después liquida a cada banda
--
-- Modelo de negocio: el checkout de Mercado Pago se crea con la cuenta de
-- KIWI, así que TODO el dinero entra a KIWI. Por eso:
--   1. Se elimina la transferencia al alias ("Ya transferí"): una banda no
--      puede verificar una plata que no entra a su cuenta. Solo existe el
--      checkout, que el webhook verifica contra la API de Mercado Pago.
--   2. La app ya no inserta ni modifica donaciones: solo el webhook (service role).
--   3. Cada donación guarda el id del pago de MP y el neto que recibió KIWI.
--      Solo las donaciones con pago verificado cuentan para el saldo.
--   4. Liquidaciones (band_payouts): lo que KIWI le transfiere a cada banda.
-- ----------------------------------------------------------------------

-- 1 y 2. Sin escrituras desde la app ------------------------------------
drop policy if exists donar_publico on public.donations;
drop policy if exists donaciones_revision_banda on public.donations;
revoke insert, update, delete on public.donations from anon, authenticated;

drop policy if exists "ver donaciones" on public.donations;
create policy "ver donaciones" on public.donations
  for select to public
  using (status = 'approved' or public.is_admin());

-- Las pendientes que quedaron del flujo del alias (pruebas) se anulan.
update public.donations set status = 'refunded' where status = 'pending';

alter table public.donations alter column status set default 'approved';

-- 3. Pago verificado y neto --------------------------------------------
alter table public.donations add column if not exists mp_payment_id text;
alter table public.donations add column if not exists net_amount numeric(12,2);
create unique index if not exists donations_mp_payment_id_key
  on public.donations (mp_payment_id) where mp_payment_id is not null;

comment on column public.donations.mp_payment_id is
  'Id del pago en Mercado Pago (lo guarda el webhook). Sin este dato la donación no fue verificada y no se liquida.';
comment on column public.donations.net_amount is
  'Monto neto que recibió KIWI después de la comisión de Mercado Pago.';

-- 4. Liquidaciones -----------------------------------------------------
create table if not exists public.band_payouts (
    id uuid primary key default gen_random_uuid(),
    band_id uuid not null references public.bands(id) on delete cascade,
    amount numeric(12,2) not null check (amount > 0),
    reference text check (char_length(reference) <= 120),
    note text check (char_length(note) <= 300),
    paid_at timestamp with time zone not null default now(),
    created_by uuid not null default auth.uid() references public.profiles(id)
);
create index if not exists band_payouts_band_id_idx on public.band_payouts (band_id, paid_at desc);

alter table public.band_payouts enable row level security;

-- La banda ve sus liquidaciones; los moderadores, todas.
drop policy if exists band_payouts_select on public.band_payouts;
create policy band_payouts_select on public.band_payouts
  for select to authenticated
  using (public.is_band_member(band_id) or public.is_admin());

-- Solo un moderador registra pagos, y a su nombre.
drop policy if exists band_payouts_insert_admin on public.band_payouts;
create policy band_payouts_insert_admin on public.band_payouts
  for insert to authenticated
  with check (public.is_admin() and created_by = (select auth.uid()));

-- Corrección de un error de carga: solo moderadores. No hay UPDATE (registro contable).
drop policy if exists band_payouts_delete_admin on public.band_payouts;
create policy band_payouts_delete_admin on public.band_payouts
  for delete to authenticated
  using (public.is_admin());

-- Saldo por banda: neto verificado - liquidado.
create or replace function public.band_balances(p_band uuid default null)
returns table(
    band_id uuid,
    band_name text,
    collected numeric,
    net_collected numeric,
    paid numeric,
    pending numeric,
    last_payout_at timestamp with time zone
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select b.id,
         b.name,
         coalesce(d.gross, 0),
         coalesce(d.net, 0),
         coalesce(p.paid, 0),
         coalesce(d.net, 0) - coalesce(p.paid, 0),
         p.last_at
  from public.bands b
  left join (
    select band_id, sum(amount) as gross, sum(coalesce(net_amount, amount)) as net
    from public.donations
    where status = 'approved' and mp_payment_id is not null
    group by band_id
  ) d on d.band_id = b.id
  left join (
    select band_id, sum(amount) as paid, max(paid_at) as last_at
    from public.band_payouts
    group by band_id
  ) p on p.band_id = b.id
  where (p_band is null and public.is_admin())
     or (p_band is not null and b.id = p_band and (public.is_band_member(p_band) or public.is_admin()))
  order by 6 desc, 2;
$$;

revoke execute on function public.band_balances(uuid) from public, anon;
grant execute on function public.band_balances(uuid) to authenticated;

-- No se puede liquidar más de lo que la banda tiene a favor.
create or replace function public.validate_payout()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_pending numeric;
begin
  -- Serializa las liquidaciones de una misma banda: dos moderadores pagando a
  -- la vez no pueden superar juntos el saldo.
  perform pg_advisory_xact_lock(hashtext('band_payout:' || new.band_id::text));

  select coalesce(sum(coalesce(net_amount, amount)), 0) into v_pending
  from public.donations
  where band_id = new.band_id and status = 'approved' and mp_payment_id is not null;

  select v_pending - coalesce(sum(amount), 0) into v_pending
  from public.band_payouts where band_id = new.band_id;

  if new.amount > v_pending then
    raise exception 'La liquidación ($%) supera el saldo pendiente de la banda ($%).', new.amount, v_pending
      using errcode = 'P0001';
  end if;
  return new;
end $$;

revoke execute on function public.validate_payout() from public, anon, authenticated;

drop trigger if exists band_payouts_validate on public.band_payouts;
create trigger band_payouts_validate
  before insert on public.band_payouts
  for each row execute function public.validate_payout();
