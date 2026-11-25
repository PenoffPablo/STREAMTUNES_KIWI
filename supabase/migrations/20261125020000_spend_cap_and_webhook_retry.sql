-- ----------------------------------------------------------------------
-- 1) Freno de emergencia que se guarda de verdad
--
-- app_config solo tiene política de SELECT: el UPDATE que hacía la app
-- afectaba 0 filas sin error, así que el freno nunca quedaba guardado.
-- En lugar de abrir UPDATE sobre toda la tabla (que dejaría a un moderador
-- cambiar la comisión de KIWI o los topes desde el cliente), una función
-- que solo cambia 'spend_cap_active' y solo para moderadores.
-- ----------------------------------------------------------------------
create or replace function public.set_spend_cap(p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Solo un moderador puede activar el freno de emergencia.' using errcode = '42501';
  end if;
  insert into public.app_config (key, value)
  values ('spend_cap_active', case when p_active then 1 else 0 end)
  on conflict (key) do update set value = excluded.value;
end $$;

revoke all on function public.set_spend_cap(boolean) from public, anon;
grant execute on function public.set_spend_cap(boolean) to authenticated;

-- ----------------------------------------------------------------------
-- 2) Un reintento del webhook no genera un "pago a devolver" falso
--
-- validate_donation corre BEFORE INSERT, antes de que Postgres evalúe el
-- ON CONFLICT del upsert del webhook. Si Mercado Pago reenvía un pago ya
-- registrado y mientras tanto la banda se suspendió (o bajó el tope), el
-- reintento fallaba con P0001 y el webhook lo anotaba en rejected_payments,
-- aunque ese pago ya cuenta en el saldo de la banda.
-- Si el pago ya existe, se deja pasar: el ON CONFLICT DO NOTHING lo descarta.
-- ----------------------------------------------------------------------
create or replace function public.validate_donation()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_max int;
begin
  if new.mp_payment_id is not null and exists (
    select 1 from public.donations where mp_payment_id = new.mp_payment_id
  ) then
    return new;
  end if;

  select value into v_max from public.app_config where key = 'max_donation_ars';
  if new.amount > v_max then
    raise exception 'El monto máximo por donación es $% ARS.', v_max using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.bands where id = new.band_id and status = 'approved') then
    raise exception 'Solo se puede donar a bandas aprobadas.' using errcode = 'P0001';
  end if;
  return new;
end $$;

revoke execute on function public.validate_donation() from public, anon, authenticated;
