-- ----------------------------------------------------------------------
-- Donaciones: el cliente ya no puede aprobarse a sí mismo
--
-- Antes, el botón "Ya transferí" insertaba la donación como 'approved' y la
-- política solo controlaba donor_id: cualquiera (incluso con la clave
-- publishable, sin la app) podía sumar plata ficticia al total de una banda,
-- aparecer en el muro y disparar el push "Recibiste un aporte".
--
-- Ahora:
--   * El cliente SOLO puede insertar donaciones 'pending'.
--   * El webhook de Mercado Pago (service role) las aprueba con el monto real.
--   * Las transferencias al alias las confirma o rechaza la banda desde su
--     panel: los miembros pueden cambiar SOLO la columna status.
--   * El trigger donations_accumulate ya suma al pasar de pending a approved.
-- ----------------------------------------------------------------------

alter table public.donations alter column status set default 'pending';

drop policy if exists donar_publico on public.donations;
create policy donar_publico on public.donations
  for insert to public
  with check (
    status = 'pending'
    and (donor_id is null or donor_id = (select auth.uid()))
  );

-- El muro público muestra solo las aprobadas; cada banda ve además las suyas
-- pendientes (para confirmarlas) y cada donante las propias.
drop policy if exists "ver donaciones" on public.donations;
create policy "ver donaciones" on public.donations
  for select to public
  using (
    status = 'approved'
    or public.is_band_member(band_id)
    or (donor_id is not null and donor_id = (select auth.uid()))
  );

-- Confirmar / rechazar: los miembros de la banda pueden pasar una donación
-- pendiente a 'approved' (la recibieron) o 'refunded' (no llegó).
drop policy if exists donaciones_revision_banda on public.donations;
create policy donaciones_revision_banda on public.donations
  for update to authenticated
  using (public.is_band_member(band_id) and status = 'pending')
  with check (public.is_band_member(band_id) and status in ('approved', 'refunded'));

-- Privilegios por columna: aunque la política permita el UPDATE, el cliente
-- solo puede tocar `status` (no el monto, la banda ni el donante).
revoke update on public.donations from anon, authenticated;
grant update (status) on public.donations to authenticated;

-- Total de la banda: además de los cambios de estado, si el webhook corrige
-- el monto de una donación YA aprobada (la banda la confirmó con el monto que
-- declaró el fan y después llega el monto real de Mercado Pago), se ajusta la
-- diferencia para que el total siempre sea la suma de las aprobadas.
create or replace function public.accumulate_donation()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.status = 'approved'
     and (tg_op = 'INSERT' or old.status is distinct from 'approved') then
    update public.bands
       set donations_collected = donations_collected + new.amount
     where id = new.band_id;
  elsif tg_op = 'UPDATE' and old.status = 'approved' and new.status <> 'approved' then
    update public.bands
       set donations_collected = greatest(0, donations_collected - old.amount)
     where id = new.band_id;
  elsif tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'approved'
        and new.amount <> old.amount then
    update public.bands
       set donations_collected = greatest(0, donations_collected + (new.amount - old.amount))
     where id = new.band_id;
  end if;
  return new;
end $$;

revoke execute on function public.accumulate_donation() from public, anon, authenticated;

drop trigger if exists donations_accumulate on public.donations;
create trigger donations_accumulate
  after insert or update of status, amount on public.donations
  for each row execute function public.accumulate_donation();

-- Limitación conocida: con la clave publishable se pueden crear donaciones
-- pendientes sin límite. Ya no afectan el total ni el muro (solo aparecen en
-- "Aportes por confirmar" de la banda, que puede rechazarlas).
