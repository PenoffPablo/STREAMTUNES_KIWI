-- ======================================================================
-- STREAMTUNES - ESQUEMA DE BASE DE DATOS (public)
--
-- Instantánea generada desde la base de producción (proyecto `streamtunes`)
-- el 2026-11-16, leyendo el catálogo de PostgreSQL. Reemplaza la versión
-- anterior de este archivo, que no coincidía con la base real
-- (ej.: donations.amount_ars / donor_user_id, que en la base son amount / donor_id).
--
-- Los cambios posteriores viven en supabase/migrations/ y se aplican encima:
--   * 20261116000000_device_tokens.sql        (push con Firebase)
--   * 20261116010000_donations_integrity.sql  (total por estado + RLS de donaciones)
--   * 20261116020000_rls_hardening.sql        (cierra políticas abiertas de tablas y Storage)
--   * 20261116030000_function_hardening.sql   (permisos de funciones, top fans y métricas)
--   * 20261124000000_donations_pending.sql    (donaciones del fan pendientes, revisión de la banda)
--
-- No incluye objetos administrados por Supabase (esquemas auth/storage,
-- event trigger `rls_auto_enable`) ni la tabla `usuarios`, que existe en la
-- misma base pero pertenece a otro proyecto (StreamTunes no la usa).
-- ======================================================================

-- ----------------------------------------------------------------------
-- 1. TIPOS
-- ----------------------------------------------------------------------
create type public.band_status as enum ('pending', 'approved', 'suspended');
create type public.donation_status as enum ('pending', 'approved', 'refunded');
create type public.member_role as enum ('owner', 'member');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

-- ----------------------------------------------------------------------
-- 2. TABLAS
-- ----------------------------------------------------------------------
create table if not exists public.profiles (
    id uuid not null,
    display_name text not null,
    avatar_url text,
    created_at timestamp with time zone default now() not null,
    is_public_profile boolean default false not null
);

create table if not exists public.app_admins (
    user_id uuid not null
);

create table if not exists public.app_config (
    key text not null,
    value integer not null
);

create table if not exists public.bands (
    id uuid default gen_random_uuid() not null,
    slug text not null,
    name text not null,
    bio text,
    genre text,
    location text,
    cover_url text,
    social_links jsonb default '{}'::jsonb not null,
    donation_goal numeric(12,2) default 0 not null,
    donations_collected numeric(12,2) default 0 not null,
    status band_status default 'pending'::band_status not null,
    created_by uuid not null,
    created_at timestamp with time zone default now() not null,
    merch_url text
);

create table if not exists public.band_members (
    band_id uuid not null,
    user_id uuid not null,
    role member_role default 'member'::member_role not null,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.band_follows (
    band_id uuid not null,
    user_id uuid not null,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.albums (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    title text not null,
    cover_url text,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.songs (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    album_id uuid,
    title text not null,
    genre text,
    audio_path text not null,
    duration_s integer not null,
    play_count bigint default 0 not null,
    hidden boolean default false not null,
    created_at timestamp with time zone default now() not null,
    cover_url text,
    lyrics_lrc text,
    audio_sha256 text,
    waveform_peaks integer[]
);

create table if not exists public.band_events (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    title text not null,
    venue text not null,
    city text default ''::text not null,
    event_date timestamp with time zone not null,
    ticket_url text,
    notes text,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.band_photos (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    photo_url text not null,
    caption text,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.band_daily_stats (
    band_id uuid not null,
    day date not null,
    plays integer default 0 not null,
    minutes integer default 0 not null,
    unique_listeners integer default 0 not null
);

create table if not exists public.donations (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    donor_id uuid,
    amount numeric(12,2) not null,
    currency text default 'ARS'::text not null,
    message text,
    is_public boolean default true not null,
    created_at timestamp with time zone default now() not null,
    status donation_status default 'approved'::donation_status not null
);

create table if not exists public.reports (
    id uuid default gen_random_uuid() not null,
    reporter_id uuid not null,
    band_id uuid,
    song_id uuid,
    reason text not null,
    status report_status default 'open'::report_status not null,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.play_events (
    id bigint generated always as identity not null,
    song_id uuid not null,
    band_id uuid not null,
    user_id uuid,
    seconds_listened integer not null,
    city text,
    created_at timestamp with time zone default now() not null
);

create table if not exists public.playlists (
    id uuid default gen_random_uuid() not null,
    user_id uuid not null,
    name text not null,
    description text,
    is_public boolean default false not null,
    created_at timestamp with time zone default now() not null,
    title text
);

create table if not exists public.playlist_songs (
    playlist_id uuid not null,
    song_id uuid not null,
    "position" integer default 0 not null,
    added_at timestamp with time zone default now() not null
);

create table if not exists public.stories (
    id uuid default gen_random_uuid() not null,
    band_id uuid not null,
    video_path text not null,
    duration_s integer not null,
    created_at timestamp with time zone default now() not null
);

-- ----------------------------------------------------------------------
-- 3. CLAVES PRIMARIAS, ÚNICAS Y CHECKS
-- ----------------------------------------------------------------------
alter table public.albums add constraint albums_pkey primary key (id);
alter table public.app_admins add constraint app_admins_pkey primary key (user_id);
alter table public.app_config add constraint app_config_pkey primary key (key);
alter table public.band_daily_stats add constraint band_daily_stats_pkey primary key (band_id, day);
alter table public.band_events add constraint band_events_pkey primary key (id);
alter table public.band_follows add constraint band_follows_pkey primary key (band_id, user_id);
alter table public.band_members add constraint band_members_pkey primary key (band_id, user_id);
alter table public.band_photos add constraint band_photos_pkey primary key (id);
alter table public.bands add constraint bands_pkey primary key (id);
alter table public.donations add constraint donations_pkey primary key (id);
alter table public.play_events add constraint play_events_pkey primary key (id);
alter table public.playlist_songs add constraint playlist_songs_pkey primary key (playlist_id, song_id);
alter table public.playlists add constraint playlists_pkey primary key (id);
alter table public.profiles add constraint profiles_pkey primary key (id);
alter table public.reports add constraint reports_pkey primary key (id);
alter table public.songs add constraint songs_pkey primary key (id);
alter table public.stories add constraint stories_pkey primary key (id);

alter table public.albums add constraint albums_band_id_title_key unique (band_id, title);
alter table public.bands add constraint bands_slug_key unique (slug);

alter table public.bands add constraint bands_donation_goal_check check (donation_goal >= 0);
alter table public.bands add constraint bands_name_check check (char_length(name) >= 2 and char_length(name) <= 60);
alter table public.bands add constraint bands_slug_check check (slug ~ '^[a-z0-9-]{2,60}$');
alter table public.donations add constraint donations_amount_check check (amount > 0);
alter table public.donations add constraint donations_message_check check (char_length(message) <= 200);
alter table public.play_events add constraint play_events_seconds_listened_check check (seconds_listened >= 0);
alter table public.playlists add constraint playlists_name_check check (char_length(name) >= 1 and char_length(name) <= 80);
alter table public.profiles add constraint profiles_display_name_check check (char_length(display_name) >= 2 and char_length(display_name) <= 50);
alter table public.reports add constraint reports_check check (band_id is not null or song_id is not null);
alter table public.reports add constraint reports_reason_check check (char_length(reason) >= 5 and char_length(reason) <= 500);
alter table public.songs add constraint songs_duration_s_check check (duration_s > 0);
alter table public.songs add constraint songs_title_check check (char_length(title) >= 1 and char_length(title) <= 120);
alter table public.stories add constraint stories_duration_s_check check (duration_s >= 1 and duration_s <= 15);

-- ----------------------------------------------------------------------
-- 4. CLAVES FORÁNEAS
-- ----------------------------------------------------------------------
alter table public.profiles add constraint profiles_id_fkey foreign key (id) references auth.users(id) on delete cascade;
alter table public.app_admins add constraint app_admins_user_id_fkey foreign key (user_id) references public.profiles(id) on delete cascade;
alter table public.bands add constraint bands_created_by_fkey foreign key (created_by) references public.profiles(id);
alter table public.band_members add constraint band_members_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.band_members add constraint band_members_user_id_fkey foreign key (user_id) references public.profiles(id) on delete cascade;
alter table public.band_follows add constraint band_follows_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.band_follows add constraint band_follows_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table public.albums add constraint albums_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.songs add constraint songs_album_id_fkey foreign key (album_id) references public.albums(id) on delete set null;
alter table public.songs add constraint songs_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.band_events add constraint band_events_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.band_photos add constraint band_photos_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.band_daily_stats add constraint band_daily_stats_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.donations add constraint donations_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.donations add constraint donations_donor_id_fkey foreign key (donor_id) references public.profiles(id);
alter table public.reports add constraint reports_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.reports add constraint reports_reporter_id_fkey foreign key (reporter_id) references public.profiles(id);
alter table public.reports add constraint reports_song_id_fkey foreign key (song_id) references public.songs(id) on delete cascade;
alter table public.play_events add constraint play_events_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;
alter table public.play_events add constraint play_events_song_id_fkey foreign key (song_id) references public.songs(id) on delete cascade;
alter table public.play_events add constraint play_events_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;
alter table public.playlists add constraint playlists_user_id_fkey foreign key (user_id) references public.profiles(id) on delete cascade;
alter table public.playlist_songs add constraint playlist_songs_playlist_id_fkey foreign key (playlist_id) references public.playlists(id) on delete cascade;
alter table public.playlist_songs add constraint playlist_songs_song_id_fkey foreign key (song_id) references public.songs(id) on delete cascade;
alter table public.stories add constraint stories_band_id_fkey foreign key (band_id) references public.bands(id) on delete cascade;

-- ----------------------------------------------------------------------
-- 5. ÍNDICES
-- ----------------------------------------------------------------------
create index band_members_user_id_idx on public.band_members using btree (user_id);
create index bands_status_idx on public.bands using btree (status);
create index donations_band_id_created_at_idx on public.donations using btree (band_id, created_at desc);
create index play_events_band_id_created_at_idx on public.play_events using btree (band_id, created_at);
create index play_events_song_id_idx on public.play_events using btree (song_id);
create index playlists_user_id_idx on public.playlists using btree (user_id);
create index reports_status_idx on public.reports using btree (status);
create unique index reports_unique_open_band on public.reports using btree (reporter_id, band_id) where (song_id is null and status = 'open'::report_status);
create unique index reports_unique_open_song on public.reports using btree (reporter_id, song_id) where (song_id is not null and status = 'open'::report_status);
create index songs_band_id_idx on public.songs using btree (band_id);
create index songs_created_at_idx on public.songs using btree (created_at desc);

-- ----------------------------------------------------------------------
-- 6. FUNCIONES
-- ----------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), split_part(new.email, '@', 1))
  );
  return new;
end $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

create or replace function public.is_band_member(p_band uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.band_members where band_id = p_band and user_id = auth.uid());
$$;

create or replace function public.is_band_owner(p_band uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.band_members
    where band_id = p_band and user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function public.add_creator_as_owner()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.band_members (band_id, user_id, role) values (new.id, new.created_by, 'owner');
  return new;
end $$;

create or replace function public.enforce_song_limit()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_songs_per_band';
  select count(*) into v_actual from public.songs where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % temas por banda.', v_max using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function public.enforce_album_limit()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_albums_per_band';
  select count(*) into v_actual from public.albums where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % álbumes por banda.', v_max using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function public.enforce_song_album_same_band()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.album_id is not null and not exists (
    select 1 from public.albums where id = new.album_id and band_id = new.band_id
  ) then
    raise exception 'El álbum no pertenece a la banda del tema.' using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function public.validate_donation()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_max int;
begin
  select value into v_max from public.app_config where key = 'max_donation_ars';
  if new.amount > v_max then
    raise exception 'El monto máximo por donación es $% ARS.', v_max using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.bands where id = new.band_id and status = 'approved') then
    raise exception 'Solo se puede donar a bandas aprobadas.' using errcode = 'P0001';
  end if;
  return new;
end $$;

-- Versión actual en producción (la migración 20261116010000 la reemplaza).
create or replace function public.accumulate_donation()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  update public.bands set donations_collected = donations_collected + new.amount where id = new.band_id;
  return new;
end $$;

create or replace function public.auto_hide_reported_song()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_limit int; v_count int;
begin
  if new.song_id is null then return new; end if;
  select value into v_limit from public.app_config where key = 'reports_to_hide';
  select count(distinct reporter_id) into v_count
    from public.reports where song_id = new.song_id and status = 'open';
  if v_count >= v_limit then
    update public.songs set hidden = true where id = new.song_id;
  end if;
  return new;
end $$;

create or replace function public.bump_play_count()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  update public.songs set play_count = play_count + 1 where id = new.song_id;
  return new;
end $$;

create or replace function public.set_band_status(p_band uuid, p_status band_status)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_admin() then
    raise exception 'Solo moderadores pueden cambiar el estado de una banda.' using errcode = '42501';
  end if;
  update public.bands set status = p_status where id = p_band;
end $$;

create or replace function public.set_song_hidden(p_song uuid, p_hidden boolean)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_admin() then
    raise exception 'Solo moderadores pueden ocultar o mostrar temas.' using errcode = '42501';
  end if;
  update public.songs set hidden = p_hidden where id = p_song;
end $$;

create or replace function public.refresh_band_daily_stats(p_day date default (current_date - 1))
returns void language sql security definer set search_path to 'public' as $$
  insert into public.band_daily_stats (band_id, day, plays, minutes, unique_listeners)
  select band_id, p_day, count(*), coalesce(sum(seconds_listened), 0) / 60, count(distinct user_id)
  from public.play_events
  where (created_at at time zone 'America/Argentina/Buenos_Aires')::date = p_day
  group by band_id
  on conflict (band_id, day) do update
    set plays = excluded.plays,
        minutes = excluded.minutes,
        unique_listeners = excluded.unique_listeners;
$$;

create or replace function public.band_aggregated_stats(p_band uuid)
returns jsonb language plpgsql security definer as $$
declare
    v_total_plays int := 0;
    v_total_seconds int := 0;
    v_recent_plays int := 0;
    v_top_songs jsonb := '[]'::jsonb;
begin
    select coalesce(sum(play_count), 0), coalesce(sum(duration_s * play_count), 0)
    into v_total_plays, v_total_seconds
    from public.songs where band_id = p_band;

    select coalesce(count(*), 0) into v_recent_plays
    from public.play_events
    where band_id = p_band and created_at >= now() - interval '7 days';

    select coalesce(jsonb_agg(sub), '[]'::jsonb) into v_top_songs
    from (
        select id, title, duration_s, play_count, 0 as recent_plays
        from public.songs
        where band_id = p_band and hidden = false
        order by play_count desc
        limit 5
    ) sub;

    return jsonb_build_object(
        'band_id', p_band,
        'total_plays', v_total_plays,
        'total_minutes', round(v_total_seconds / 60.0),
        'last_7_days_plays', v_recent_plays,
        'top_songs', v_top_songs
    );
end;
$$;

create or replace function public.band_top_fans(p_band uuid, p_days integer default 30)
returns table(rank integer, user_id uuid, display_name text, avatar_url text, minutes_listened integer, is_public boolean)
language plpgsql security definer as $$
begin
    return query
    select
        row_number() over (order by coalesce(sum(pe.seconds_listened), 0) desc)::int as rank,
        p.id as user_id,
        case when p.is_public_profile then p.display_name else 'Fan anónimo' end as display_name,
        case when p.is_public_profile then p.avatar_url else null end as avatar_url,
        round(coalesce(sum(pe.seconds_listened), 0) / 60.0)::int as minutes_listened,
        p.is_public_profile as is_public
    from public.profiles p
    left join public.play_events pe
      on pe.user_id = p.id and pe.band_id = p_band
     and pe.created_at >= now() - (p_days || ' days')::interval
    group by p.id, p.display_name, p.avatar_url, p.is_public_profile
    order by minutes_listened desc
    limit 10;
end;
$$;

create or replace function public.band_top_listeners(p_band uuid, p_days integer default 30)
returns table(user_id uuid, display_name text, minutes bigint)
language sql stable security definer set search_path to 'public' as $$
  select pe.user_id, p.display_name, sum(pe.seconds_listened) / 60
  from public.play_events pe
  join public.profiles p on p.id = pe.user_id
  where pe.band_id = p_band
    and public.is_band_member(p_band)
    and pe.created_at >= now() - make_interval(days => p_days)
  group by pe.user_id, p.display_name
  order by 3 desc
  limit 10;
$$;

-- ----------------------------------------------------------------------
-- 7. TRIGGERS
-- ----------------------------------------------------------------------
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
create trigger on_band_created after insert on public.bands for each row execute function public.add_creator_as_owner();
create trigger albums_limit before insert on public.albums for each row execute function public.enforce_album_limit();
create trigger songs_limit before insert on public.songs for each row execute function public.enforce_song_limit();
create trigger songs_album_same_band before insert or update of album_id, band_id on public.songs for each row execute function public.enforce_song_album_same_band();
create trigger donations_validate before insert on public.donations for each row execute function public.validate_donation();
create trigger donations_accumulate after insert on public.donations for each row execute function public.accumulate_donation();
create trigger play_events_bump after insert on public.play_events for each row execute function public.bump_play_count();
create trigger reports_auto_hide after insert on public.reports for each row execute function public.auto_hide_reported_song();

-- ----------------------------------------------------------------------
-- 8. ROW LEVEL SECURITY (tal como está hoy en producción)
-- ----------------------------------------------------------------------
alter table public.albums enable row level security;
alter table public.app_admins enable row level security;
alter table public.app_config enable row level security;
alter table public.band_daily_stats enable row level security;
alter table public.band_events enable row level security;
alter table public.band_follows enable row level security;
alter table public.band_members enable row level security;
alter table public.band_photos enable row level security;
alter table public.bands enable row level security;
alter table public.donations enable row level security;
alter table public.play_events enable row level security;
alter table public.playlist_songs enable row level security;
alter table public.playlists enable row level security;
alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.songs enable row level security;
alter table public.stories enable row level security;

create policy "banda gestiona albums" on public.albums for all to authenticated using (is_band_member(band_id)) with check (is_band_member(band_id));
create policy "ver albums" on public.albums for select to public using ((exists (select 1 from bands b where b.id = albums.band_id and b.status = 'approved'::band_status)) or is_band_member(band_id));
create policy "ver si soy admin" on public.app_admins for select to authenticated using (user_id = auth.uid());
create policy "config legible" on public.app_config for select to public using (true);
create policy "banda ve sus stats" on public.band_daily_stats for select to authenticated using (is_band_member(band_id));
create policy band_events_select on public.band_events for select to public using (true);
create policy band_events_write_member on public.band_events for all to authenticated using (is_band_member(band_id)) with check (is_band_member(band_id));
create policy band_follows_delete on public.band_follows for delete to public using (true);
create policy band_follows_insert on public.band_follows for insert to public with check (true);
create policy band_follows_select on public.band_follows for select to public using (true);
create policy "owner agrega miembros" on public.band_members for insert to authenticated with check (is_band_owner(band_id));
create policy "owner quita miembros" on public.band_members for delete to authenticated using (is_band_owner(band_id) or user_id = auth.uid());
create policy "ver miembros" on public.band_members for select to authenticated using (user_id = auth.uid() or is_band_member(band_id));
create policy band_photos_all on public.band_photos for all to public using (true) with check (true);
create policy band_photos_select on public.band_photos for select to public using (true);
create policy band_photos_write_member on public.band_photos for all to authenticated using (is_band_member(band_id)) with check (is_band_member(band_id));
create policy "crear banda" on public.bands for insert to authenticated with check (created_by = auth.uid() and status = 'pending'::band_status);
create policy "editar banda (owner)" on public.bands for update to authenticated using (is_band_owner(id) or is_admin()) with check (is_band_owner(id) or is_admin());
create policy "ver bandas" on public.bands for select to public using (status = 'approved'::band_status or created_by = auth.uid() or is_band_member(id) or is_admin());
create policy donaciones_authenticated on public.donations for all to authenticated using (true) with check (true);
create policy donar_publico on public.donations for insert to public with check (true);
create policy "ver donaciones" on public.donations for select to public using (true);
create policy "banda ve sus reproducciones" on public.play_events for select to authenticated using (is_band_member(band_id));
create policy "registrar reproduccion" on public.play_events for insert to authenticated with check (user_id = auth.uid() and exists (select 1 from songs s where s.id = play_events.song_id and s.band_id = play_events.band_id));
create policy "gestionar canciones de mis playlists" on public.playlist_songs for all to public using (true) with check (true);
create policy "ver canciones de playlist" on public.playlist_songs for select to public using (true);
create policy "gestionar mis playlists" on public.playlists for all to authenticated using (true) with check (true);
create policy public_create_playlists on public.playlists for insert to public with check (true);
create policy "ver playlists" on public.playlists for select to public using (true);
create policy "editar mi perfil" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "perfiles visibles" on public.profiles for select to authenticated using (true);
create policy "admin resuelve reportes" on public.reports for update to authenticated using (is_admin()) with check (is_admin());
create policy reportar on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "ver reportes" on public.reports for select to authenticated using (reporter_id = auth.uid() or is_admin());
create policy "banda gestiona songs" on public.songs for all to authenticated using (true) with check (true);
create policy public_gestiona_songs on public.songs for all to public using (true) with check (true);
create policy "ver songs" on public.songs for select to public using (true);
create policy "banda gestiona stories" on public.stories for all to authenticated using (is_band_member(band_id)) with check (is_band_member(band_id));
create policy "ver stories" on public.stories for select to public using ((exists (select 1 from bands b where b.id = stories.band_id and b.status = 'approved'::band_status)) or is_band_member(band_id));

-- ----------------------------------------------------------------------
-- 9. REALTIME
-- ----------------------------------------------------------------------
alter publication supabase_realtime add table public.donations;

-- ----------------------------------------------------------------------
-- 10. CONFIGURACIÓN INICIAL
-- ----------------------------------------------------------------------
insert into public.app_config (key, value) values
    ('max_songs_per_band', 20),
    ('max_albums_per_band', 2),
    ('max_donation_ars', 5000),
    ('reports_to_hide', 3),
    ('spend_cap_active', 0)
on conflict (key) do nothing;
