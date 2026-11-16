-- ----------------------------------------------------------------------
-- Endurecimiento de RLS
--
-- Las políticas permisivas se combinan con OR: alcanza con que UNA sea
-- `using (true)` para que cualquiera pueda hacer la operación, aunque existan
-- otras políticas más estrictas. Acá se eliminan esas políticas abiertas y se
-- dejan solo las que corresponden a cada caso de uso de la app.
-- ----------------------------------------------------------------------

-- ============================ songs ===================================
-- Antes: `public_gestiona_songs` (rol public, FOR ALL, true) -> cualquiera,
-- incluso SIN cuenta, podía editar o borrar cualquier canción.
drop policy if exists public_gestiona_songs on public.songs;
drop policy if exists "banda gestiona songs" on public.songs;
drop policy if exists "ver songs" on public.songs;

-- Lectura: temas visibles, más los ocultos para su banda y moderadores.
create policy songs_select on public.songs
  for select to public
  using (hidden = false or public.is_band_member(band_id) or public.is_admin());

-- Subir: solo miembros de la banda.
create policy songs_insert_member on public.songs
  for insert to authenticated
  with check (public.is_band_member(band_id));

-- Editar: miembros de la banda; moderadores (ocultar temas reportados).
create policy songs_update_member_or_admin on public.songs
  for update to authenticated
  using (public.is_band_member(band_id) or public.is_admin())
  with check (public.is_band_member(band_id) or public.is_admin());

-- Borrar: miembros de la banda o moderadores.
create policy songs_delete_member_or_admin on public.songs
  for delete to authenticated
  using (public.is_band_member(band_id) or public.is_admin());

-- ============================ playlists ===============================
-- Antes: cualquiera podía crear playlists a nombre de otro y cualquier usuario
-- logueado podía editar o borrar las playlists de los demás.
drop policy if exists "gestionar mis playlists" on public.playlists;
drop policy if exists public_create_playlists on public.playlists;
drop policy if exists "ver playlists" on public.playlists;

create policy playlists_select on public.playlists
  for select to public
  using (is_public or user_id = (select auth.uid()));

create policy playlists_insert_own on public.playlists
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy playlists_update_own on public.playlists
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy playlists_delete_own on public.playlists
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ============================ playlist_songs ==========================
-- Antes: cualquiera podía agregar o quitar temas de cualquier playlist.
drop policy if exists "gestionar canciones de mis playlists" on public.playlist_songs;
drop policy if exists "ver canciones de playlist" on public.playlist_songs;

create policy playlist_songs_select on public.playlist_songs
  for select to public
  using (exists (
    select 1 from public.playlists p
    where p.id = playlist_songs.playlist_id
      and (p.is_public or p.user_id = (select auth.uid()))
  ));

create policy playlist_songs_write_own on public.playlist_songs
  for all to authenticated
  using (exists (
    select 1 from public.playlists p
    where p.id = playlist_songs.playlist_id and p.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.playlists p
    where p.id = playlist_songs.playlist_id and p.user_id = (select auth.uid())
  ));

-- ============================ band_photos =============================
-- Antes: `band_photos_all` (rol public, FOR ALL, true) anulaba la política de
-- miembros. Quedan `band_photos_select` (lectura) y `band_photos_write_member`.
drop policy if exists band_photos_all on public.band_photos;

-- ============================ band_follows ============================
-- Antes: cualquiera podía seguir o dejar de seguir bandas EN NOMBRE DE OTRO.
drop policy if exists band_follows_insert on public.band_follows;
drop policy if exists band_follows_delete on public.band_follows;

create policy band_follows_insert_own on public.band_follows
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- La app usa upsert (INSERT ... ON CONFLICT DO UPDATE), que requiere UPDATE.
create policy band_follows_update_own on public.band_follows
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy band_follows_delete_own on public.band_follows
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ============================ storage =================================
-- Antes: cualquier usuario logueado podía subir audio y subir o PISAR portadas
-- de cualquier banda; en `photos`, cualquiera SIN cuenta podía subir, pisar y
-- borrar. Se dejan solo las políticas de miembros (carpeta = id de la banda),
-- ahora también para el bucket `photos`.
drop policy if exists audio_insert_authenticated on storage.objects;
drop policy if exists covers_insert_authenticated on storage.objects;
drop policy if exists covers_update_authenticated on storage.objects;
drop policy if exists "insert photos" on storage.objects;

drop policy if exists "miembros suben archivos" on storage.objects;
create policy "miembros suben archivos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = any (array['audio', 'covers', 'stories', 'photos'])
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "miembros actualizan archivos" on storage.objects;
create policy "miembros actualizan archivos" on storage.objects
  for update to authenticated
  using (
    bucket_id = any (array['audio', 'covers', 'stories', 'photos'])
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = any (array['audio', 'covers', 'stories', 'photos'])
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "miembros borran archivos" on storage.objects;
create policy "miembros borran archivos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = any (array['audio', 'covers', 'stories', 'photos'])
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );
