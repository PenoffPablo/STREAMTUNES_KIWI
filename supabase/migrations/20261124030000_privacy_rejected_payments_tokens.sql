-- ======================================================================
-- 1) Aportes anónimos de verdad
-- ----------------------------------------------------------------------
-- Antes cualquiera (incluso sin cuenta) podía leer TODAS las columnas de
-- `donations`, incluido `donor_id`: "Fan anónimo" solo lo armaba la app.
-- Ahora el nombre visible se guarda en `donor_name` (NULL si es anónimo) y
-- el público solo puede leer columnas no sensibles. El donante, el id del
-- pago y el neto quedan para la service role y para RPCs de moderación.
-- ======================================================================
alter table public.donations add column if not exists donor_name text;

create or replace function public.set_donation_donor_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.donor_name := case
    when new.is_public and new.donor_id is not null
      then (select p.display_name from public.profiles p where p.id = new.donor_id)
  end;
  return new;
end $$;

revoke all on function public.set_donation_donor_name() from public, anon, authenticated;

drop trigger if exists donations_set_donor_name on public.donations;
create trigger donations_set_donor_name
  before insert or update of is_public, donor_id on public.donations
  for each row execute function public.set_donation_donor_name();

-- Completa las filas que ya existían.
update public.donations d
   set donor_name = case when d.is_public then p.display_name end
  from public.profiles p
 where p.id = d.donor_id;

-- Solo columnas no sensibles para la app (la RLS de filas sigue igual).
revoke select on public.donations from anon, authenticated;
grant select (id, band_id, amount, currency, message, is_public, donor_name, status, created_at)
  on public.donations to anon, authenticated;

-- Últimos pagos verificados, con neto e id de Mercado Pago: solo moderadores.
create or replace function public.admin_recent_payments(p_limit int default 20)
returns table (
  id uuid,
  band_id uuid,
  band_name text,
  donor_name text,
  amount numeric,
  net_amount numeric,
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
    select d.id, d.band_id, b.name, d.donor_name, d.amount, d.net_amount,
           d.mp_payment_id, d.message, d.is_public, d.status::text, d.created_at
      from public.donations d
      join public.bands b on b.id = d.band_id
     where d.status = 'approved' and d.mp_payment_id is not null
     order by d.created_at desc
     limit least(greatest(coalesce(p_limit, 20), 1), 100);
end $$;

revoke all on function public.admin_recent_payments(int) from public, anon;
grant execute on function public.admin_recent_payments(int) to authenticated;

-- ======================================================================
-- 2) Pagos a devolver
-- ----------------------------------------------------------------------
-- Pagos que Mercado Pago aprobó pero la base no pudo registrar como aporte
-- (banda suspendida, monto mayor al tope, pago sin banda). La plata está en
-- la cuenta de KIWI: el moderador los ve en su panel y los devuelve.
-- Solo los escribe el webhook (service role).
-- ======================================================================
create table if not exists public.rejected_payments (
  id uuid primary key default gen_random_uuid(),
  mp_payment_id text not null unique,
  band_id uuid references public.bands(id) on delete set null,
  donor_id uuid references public.profiles(id) on delete set null,
  amount numeric(12,2) not null,
  reason text not null,
  created_at timestamptz not null default now(),
  refunded_at timestamptz,
  refunded_by uuid references public.profiles(id) on delete set null
);

alter table public.rejected_payments enable row level security;

drop policy if exists "rejected_payments_admin_select" on public.rejected_payments;
create policy "rejected_payments_admin_select" on public.rejected_payments
  for select to authenticated using (public.is_admin());

revoke all on public.rejected_payments from anon, authenticated;
grant select on public.rejected_payments to authenticated;

-- El moderador marca que ya devolvió el pago desde Mercado Pago.
create or replace function public.mark_rejected_payment_refunded(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Solo un moderador puede marcar devoluciones.' using errcode = '42501';
  end if;
  update public.rejected_payments
     set refunded_at = now(), refunded_by = auth.uid()
   where id = p_id and refunded_at is null;
  if not found then
    raise exception 'Ese pago ya estaba marcado como devuelto o no existe.' using errcode = 'P0001';
  end if;
end $$;

revoke all on function public.mark_rejected_payment_refunded(uuid) from public, anon;
grant execute on function public.mark_rejected_payment_refunded(uuid) to authenticated;

-- ======================================================================
-- 3) Token push del dispositivo
-- ----------------------------------------------------------------------
-- Si el usuario A cerró sesión sin red, su token quedaba a su nombre y la
-- RLS impedía que B (mismo teléfono) lo reasignara: B no recibía push y el
-- teléfono seguía recibiendo los de A. Esta función reasigna el token al
-- usuario que inició sesión.
-- ======================================================================
create or replace function public.register_device_token(p_token text, p_platform text default 'android')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Tenés que iniciar sesión para recibir notificaciones.' using errcode = '42501';
  end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then
    raise exception 'Token de notificaciones inválido.' using errcode = 'P0001';
  end if;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, v_user, coalesce(nullif(p_platform, ''), 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end $$;

revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;
