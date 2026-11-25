-- ----------------------------------------------------------------------
-- Comisión de KIWI: 20% del neto para sostener la app
--
-- De cada aporte verificado, KIWI retiene un porcentaje (app_config
-- 'kiwi_commission_pct', 20 por defecto) de lo que llega después de la
-- comisión de Mercado Pago. Paga servidores, almacenamiento y la operación;
-- no es ganancia del equipo.
--
-- Ejemplo: el fan aporta $1000, MP cobra $60 y quedan $940. KIWI retiene
-- $188 y a la banda le corresponden $752.
--
-- La regla se hace cumplir en la base: el saldo de cada banda y el tope de
-- cada liquidación ya descuentan la comisión, así que un moderador no puede
-- liquidar más de lo que le corresponde a la banda.
-- ----------------------------------------------------------------------

-- 1. Porcentaje configurable ------------------------------------------------
insert into public.app_config (key, value)
values ('kiwi_commission_pct', 20)
on conflict (key) do nothing;

-- 2. Comisión guardada en cada aporte ----------------------------------------
-- Se calcula al insertar y queda fija: si el porcentaje cambia, los aportes
-- anteriores conservan la comisión con la que entraron.
alter table public.donations add column if not exists kiwi_fee numeric(12,2) not null default 0;

comment on column public.donations.kiwi_fee is
  'Comisión de KIWI para sostener la app: kiwi_commission_pct % del neto (después de Mercado Pago). Se fija al insertar.';

create or replace function public.set_donation_kiwi_fee()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare v_pct numeric;
begin
  select value into v_pct from public.app_config where key = 'kiwi_commission_pct';
  new.kiwi_fee := round(coalesce(new.net_amount, new.amount) * coalesce(v_pct, 20) / 100, 2);
  return new;
end $$;

revoke execute on function public.set_donation_kiwi_fee() from public, anon, authenticated;

drop trigger if exists donations_set_kiwi_fee on public.donations;
create trigger donations_set_kiwi_fee
  before insert on public.donations
  for each row execute function public.set_donation_kiwi_fee();

-- Aportes que ya estaban (al momento de esta migración, solo pruebas).
update public.donations
   set kiwi_fee = round(coalesce(net_amount, amount) * 20 / 100, 2)
 where kiwi_fee = 0;

-- kiwi_fee no se agrega a los grants de columnas de anon/authenticated:
-- el público no lo ve. Lo leen el admin (RPCs) y la banda (band_balances).

-- 3. Saldo por banda: neto - comisión KIWI - liquidado -----------------------
drop function if exists public.band_balances(uuid);

create function public.band_balances(p_band uuid default null)
returns table(
    band_id uuid,
    band_name text,
    collected numeric,
    net_collected numeric,
    kiwi_fee numeric,
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
         coalesce(d.fee, 0),
         coalesce(p.paid, 0),
         coalesce(d.net, 0) - coalesce(d.fee, 0) - coalesce(p.paid, 0),
         p.last_at
  from public.bands b
  left join (
    select band_id,
           sum(amount) as gross,
           sum(coalesce(net_amount, amount)) as net,
           sum(kiwi_fee) as fee
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
  order by 7 desc, 2;
$$;

revoke execute on function public.band_balances(uuid) from public, anon;
grant execute on function public.band_balances(uuid) to authenticated;

-- 4. Tope de cada liquidación: lo que le corresponde a la banda --------------
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

  select coalesce(sum(coalesce(net_amount, amount) - kiwi_fee), 0) into v_pending
  from public.donations
  where band_id = new.band_id and status = 'approved' and mp_payment_id is not null;

  select v_pending - coalesce(sum(amount), 0) into v_pending
  from public.band_payouts where band_id = new.band_id;

  if new.amount > v_pending then
    raise exception 'La liquidación ($%) supera lo que le corresponde a la banda ($%, ya descontada la comisión de KIWI).',
      new.amount, v_pending
      using errcode = 'P0001';
  end if;
  return new;
end $$;

revoke execute on function public.validate_payout() from public, anon, authenticated;

-- 5. Pagos recientes del panel de moderación, con la comisión --------------
drop function if exists public.admin_recent_payments(int);

create function public.admin_recent_payments(p_limit int default 20)
returns table (
  id uuid,
  band_id uuid,
  band_name text,
  donor_name text,
  amount numeric,
  net_amount numeric,
  kiwi_fee numeric,
  mp_payment_id text,
  message text,
  is_public boolean,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Solo un moderador puede ver los pagos.' using errcode = '42501';
  end if;
  return query
    select d.id, d.band_id, b.name, d.donor_name, d.amount, d.net_amount, d.kiwi_fee,
           d.mp_payment_id, d.message, d.is_public, d.status::text, d.created_at
      from public.donations d
      join public.bands b on b.id = d.band_id
     where d.status = 'approved' and d.mp_payment_id is not null
     order by d.created_at desc
     limit least(greatest(coalesce(p_limit, 20), 1), 100);
end $$;

revoke all on function public.admin_recent_payments(int) from public, anon;
grant execute on function public.admin_recent_payments(int) to authenticated;
