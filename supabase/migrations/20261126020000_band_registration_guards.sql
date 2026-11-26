-- ----------------------------------------------------------------------
-- Registro de bandas sin atajos: la aprobación es solo de un moderador
--
-- Problemas que cierra (antes de habilitar "Registrar mi banda" en la app):
--   1. El dueño de una banda podía hacer UPDATE de CUALQUIER columna de su
--      banda, incluida `status`: podía aprobarse a sí mismo y saltear la
--      moderación anti-copyright. También podía cambiar `donations_collected`
--      o `created_by`.
--   2. Al crear la banda podía mandar `donations_collected` inflado.
--   3. Una banda PENDIENTE podía subir temas (solo se pedía ser miembro) y
--      esos temas se veían en el inicio público sin haber sido aprobada.
-- ----------------------------------------------------------------------

-- 1 y 2. Columnas que solo cambia un moderador (o el sistema) ------------
-- Desde la app (rol authenticated/anon) y sin ser moderador:
--   * al crear: la banda nace pendiente, sin recaudación y con fecha actual;
--   * al editar: no se tocan estado, recaudación, creador, id ni fecha.
-- Las funciones del sistema (por ejemplo, la que suma los aportes) corren
-- como su dueño, no como authenticated, así que no pasan por este control.
-- SECURITY INVOKER a propósito: `current_user` tiene que ser el rol de quien
-- hace el cambio (authenticated desde la app, el dueño de la función si viene
-- de una función del sistema). Con SECURITY DEFINER sería siempre postgres.
create or replace function public.guard_band_columns()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.donations_collected := 0;
    new.created_at := now();
    new.created_by := auth.uid();
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Solo un moderador puede aprobar o suspender una banda.' using errcode = '42501';
  end if;
  if new.donations_collected is distinct from old.donations_collected
     or new.created_by is distinct from old.created_by
     or new.id is distinct from old.id
     or new.created_at is distinct from old.created_at then
    raise exception 'Esos datos de la banda no se pueden modificar.' using errcode = '42501';
  end if;
  return new;
end $$;

revoke execute on function public.guard_band_columns() from public, anon, authenticated;

drop trigger if exists bands_guard_columns on public.bands;
create trigger bands_guard_columns
  before insert or update on public.bands
  for each row execute function public.guard_band_columns();

-- 3. Temas: solo bandas aprobadas publican y se ven en público ----------
create or replace function public.is_band_approved(p_band uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (select 1 from public.bands where id = p_band and status = 'approved');
$$;

revoke execute on function public.is_band_approved(uuid) from public;
grant execute on function public.is_band_approved(uuid) to anon, authenticated;

drop policy if exists songs_insert_member on public.songs;
create policy songs_insert_member on public.songs
  for insert to authenticated
  with check (public.is_band_member(band_id) and public.is_band_approved(band_id));

-- El público ve los temas visibles de bandas aprobadas; los miembros y los
-- moderadores ven todos los de su banda (también si está suspendida).
drop policy if exists songs_select on public.songs;
create policy songs_select on public.songs
  for select to public
  using (
    (hidden = false and public.is_band_approved(band_id))
    or public.is_band_member(band_id)
    or public.is_admin()
  );
