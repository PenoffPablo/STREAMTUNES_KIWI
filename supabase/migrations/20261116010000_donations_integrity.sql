-- ----------------------------------------------------------------------
-- Integridad de donaciones
-- ----------------------------------------------------------------------

-- 1. El total de la banda solo suma donaciones APROBADAS, y acompaña los
--    cambios de estado (pending -> approved suma; approved -> refunded resta).
--    Antes sumaba toda fila insertada, sin mirar el estado.
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
  end if;
  return new;
end $$;

drop trigger if exists donations_accumulate on public.donations;
create trigger donations_accumulate
  after insert or update of status on public.donations
  for each row execute function public.accumulate_donation();

-- 2. RLS. La política `donaciones_authenticated` (FOR ALL USING true) dejaba a
--    cualquier usuario logueado MODIFICAR o BORRAR cualquier donación.
drop policy if exists donaciones_authenticated on public.donations;

-- Insertar: se puede donar sin cuenta (donor_id nulo) o a nombre propio,
-- nunca a nombre de otro usuario.
drop policy if exists donar_publico on public.donations;
create policy donar_publico on public.donations
  for insert to public
  with check (donor_id is null or donor_id = (select auth.uid()));

-- Lectura pública del muro (sin cambios). UPDATE/DELETE quedan solo para la
-- service role (webhook de Mercado Pago y administración).
