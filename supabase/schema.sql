-- ======================================================================
-- STREAMTUNES - ESQUEMA CONSOLIDADO IDEMPOTENTE DE SUPABASE
-- Plataforma nativa de música independiente (Colectivo Under)
-- ======================================================================

-- Habilitar extensiones necesarias
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------
-- 1. TABLA: app_config (Topes y control de costos)
-- ----------------------------------------------------------------------
create table if not exists public.app_config (
    key text primary key,
    value text not null,
    description text,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Valores iniciales del Colectivo
insert into public.app_config (key, value, description) values
    ('max_songs_per_band', '20', 'Tope estricto de canciones por banda'),
    ('max_albums_per_band', '2', 'Tope estricto de álbumes o EPs por banda'),
    ('max_donation_ars', '5000', 'Tope máximo de donación en pesos argentinos por transacción'),
    ('reports_to_hide', '3', 'Cantidad de reportes abiertos para ocultar canción automáticamente'),
    ('spend_cap_active', '0', 'Interruptor de emergencia (1 = pico viral, bloquea subidas/streaming pesado)')
on conflict (key) do nothing;

-- ----------------------------------------------------------------------
-- 2. TABLA: profiles (Separación Usuario != Banda y Ley de Privacidad)
-- ----------------------------------------------------------------------
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null default 'Fan anónimo',
    avatar_url text,
    is_public_profile boolean not null default false, -- Opt-in explícito para Top Fans
    is_anonymous boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 3. TABLA: app_admins (Moderadores del Colectivo)
-- ----------------------------------------------------------------------
create table if not exists public.app_admins (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 4. TABLA: bands (Bandas independientes)
-- ----------------------------------------------------------------------
create table if not exists public.bands (
    id uuid primary key default uuid_generate_v4(),
    slug text unique not null,
    name text not null,
    bio text,
    genre text not null default 'Indie',
    location text,
    cover_url text,
    merch_url text, -- Tienda externa de remeras/vinilos
    social_links jsonb default '{}'::jsonb,
    donation_goal numeric(12,2) default 50000.00,
    donations_collected numeric(12,2) default 0.00,
    status text not null default 'pending' check (status in ('pending', 'approved', 'suspended')),
    created_by uuid references public.profiles(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 5. TABLA: band_members (Miembros de la banda)
-- ----------------------------------------------------------------------
create table if not exists public.band_members (
    band_id uuid not null references public.bands(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    role text not null default 'member' check (role in ('owner', 'member')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (band_id, user_id)
);

-- ----------------------------------------------------------------------
-- 6. TABLA: band_follows (Seguimiento instantáneo vía QR)
-- ----------------------------------------------------------------------
create table if not exists public.band_follows (
    band_id uuid not null references public.bands(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (band_id, user_id)
);

-- ----------------------------------------------------------------------
-- 7. TABLA: albums
-- ----------------------------------------------------------------------
create table if not exists public.albums (
    id uuid primary key default uuid_generate_v4(),
    band_id uuid not null references public.bands(id) on delete cascade,
    title text not null,
    release_year int,
    cover_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 8. TABLA: songs
-- ----------------------------------------------------------------------
create table if not exists public.songs (
    id uuid primary key default uuid_generate_v4(),
    band_id uuid not null references public.bands(id) on delete cascade,
    album_id uuid references public.albums(id) on delete set null,
    title text not null,
    genre text not null default 'Indie',
    audio_path text not null,
    cover_url text,
    duration_s int not null check (duration_s >= 60), -- Regla: mínimo 60 segundos
    lyrics_lrc text, -- Formato [mm:ss.xx]
    audio_sha256 text not null,
    waveform_peaks jsonb default '[]'::jsonb, -- Array normalizado de 40 muestras
    play_count bigint not null default 0,
    hidden boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 9. TABLA: band_events (Agenda de shows en vivo)
-- ----------------------------------------------------------------------
create table if not exists public.band_events (
    id uuid primary key default uuid_generate_v4(),
    band_id uuid not null references public.bands(id) on delete cascade,
    title text not null,
    venue text not null,
    city text not null,
    event_date timestamp with time zone not null,
    ticket_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 10. TABLA: band_photos (Galería de recitales)
-- ----------------------------------------------------------------------
create table if not exists public.band_photos (
    id uuid primary key default uuid_generate_v4(),
    band_id uuid not null references public.bands(id) on delete cascade,
    photo_url text not null,
    caption text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 11. TABLA: donations (Muro público y transparente)
-- ----------------------------------------------------------------------
create table if not exists public.donations (
    id uuid primary key default uuid_generate_v4(),
    band_id uuid not null references public.bands(id) on delete cascade,
    donor_user_id uuid references public.profiles(id) on delete set null,
    donor_name text not null default 'Fan anónimo',
    amount_ars numeric(10,2) not null check (amount_ars > 0),
    message text,
    is_anonymous boolean not null default false,
    status text not null default 'approved' check (status in ('pending', 'approved', 'refunded')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 12. TABLA: reports (Moderación comunitaria anti-copyright)
-- ----------------------------------------------------------------------
create table if not exists public.reports (
    id uuid primary key default uuid_generate_v4(),
    song_id uuid not null references public.songs(id) on delete cascade,
    reporter_user_id uuid not null references public.profiles(id) on delete cascade,
    reason text not null,
    status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 13. TABLA: play_events (Métricas y Top Fans)
-- ----------------------------------------------------------------------
create table if not exists public.play_events (
    id uuid primary key default uuid_generate_v4(),
    song_id uuid not null references public.songs(id) on delete cascade,
    band_id uuid not null references public.bands(id) on delete cascade,
    user_id uuid references public.profiles(id) on delete set null,
    seconds_listened int not null check (seconds_listened >= 5),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ----------------------------------------------------------------------
-- 14. TABLA: playlists y playlist_songs
-- ----------------------------------------------------------------------
create table if not exists public.playlists (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    title text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.playlist_songs (
    playlist_id uuid not null references public.playlists(id) on delete cascade,
    song_id uuid not null references public.songs(id) on delete cascade,
    added_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (playlist_id, song_id)
);

-- ======================================================================
-- TRIGGERS DE NEGOCIO EN BASE DE DATOS
-- ======================================================================

-- 1. Trigger de usuario automático al registrarse o iniciar anónimamente
create or replace function public.handle_new_user()
returns trigger as $$
declare
    v_is_anon boolean;
    v_display_name text;
begin
    v_is_anon := coalesce((new.raw_app_meta_data->>'provider') = 'anonymous', false);
    if v_is_anon then
        v_display_name := 'Fan anónimo';
    else
        v_display_name := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));
    end if;

    insert into public.profiles (id, display_name, avatar_url, is_public_profile, is_anonymous)
    values (new.id, v_display_name, new.raw_user_meta_data->>'avatar_url', false, v_is_anon)
    on conflict (id) do nothing;
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 2. Trigger: enforce_song_limit (Máximo 20 canciones por banda)
create or replace function public.enforce_song_limit()
returns trigger as $$
declare
    v_count int;
    v_max int;
begin
    select coalesce(value::int, 20) into v_max
    from public.app_config where key = 'max_songs_per_band';
    if v_max is null then v_max := 20; end if;

    select count(*) into v_count
    from public.songs
    where band_id = new.band_id;

    if v_count >= v_max then
        raise exception 'Cupo alcanzado: La banda ya tiene % canciones subidas (máximo permitido: %)', v_count, v_max;
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists check_song_limit on public.songs;
create trigger check_song_limit
    before insert on public.songs
    for each row execute function public.enforce_song_limit();

-- 3. Trigger: enforce_album_limit (Máximo 2 álbumes por banda)
create or replace function public.enforce_album_limit()
returns trigger as $$
declare
    v_count int;
    v_max int;
begin
    select coalesce(value::int, 2) into v_max
    from public.app_config where key = 'max_albums_per_band';
    if v_max is null then v_max := 2; end if;

    select count(*) into v_count
    from public.albums
    where band_id = new.band_id;

    if v_count >= v_max then
        raise exception 'Cupo alcanzado: La banda ya tiene % álbumes/EPs creados (máximo permitido: %)', v_count, v_max;
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists check_album_limit on public.albums;
create trigger check_album_limit
    before insert on public.albums
    for each row execute function public.enforce_album_limit();

-- 4. Trigger: validate_donation y accumulate_donation
create or replace function public.validate_donation()
returns trigger as $$
declare
    v_max numeric;
begin
    select coalesce(value::numeric, 5000.0) into v_max
    from public.app_config where key = 'max_donation_ars';
    if v_max is null then v_max := 5000.0; end if;

    if new.amount_ars > v_max then
        raise exception 'El monto de la donación ($% ARS) supera el tope permitido de $% ARS', new.amount_ars, v_max;
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists check_donation_amount on public.donations;
create trigger check_donation_amount
    before insert on public.donations
    for each row execute function public.validate_donation();

create or replace function public.accumulate_donation()
returns trigger as $$
begin
    if new.status = 'approved' and (tg_op = 'INSERT' or old.status <> 'approved') then
        update public.bands
        set donations_collected = donations_collected + new.amount_ars
        where id = new.band_id;
    elsif tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'refunded' then
        update public.bands
        set donations_collected = greatest(0, donations_collected - old.amount_ars)
        where id = new.band_id;
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists sync_donation_total on public.donations;
create trigger sync_donation_total
    after insert or update on public.donations
    for each row execute function public.accumulate_donation();

-- 5. Trigger: auto_hide_reported_song (Oculta tras 3 reportes abiertos de usuarios distintos)
create or replace function public.auto_hide_reported_song()
returns trigger as $$
declare
    v_threshold int;
    v_unique_reports int;
begin
    select coalesce(value::int, 3) into v_threshold
    from public.app_config where key = 'reports_to_hide';
    if v_threshold is null then v_threshold := 3; end if;

    select count(distinct reporter_user_id) into v_unique_reports
    from public.reports
    where song_id = new.song_id and status = 'open';

    if v_unique_reports >= v_threshold then
        update public.songs
        set hidden = true
        where id = new.song_id;
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_auto_hide_song on public.reports;
create trigger trigger_auto_hide_song
    after insert or update on public.reports
    for each row execute function public.auto_hide_reported_song();

-- 6. Trigger: incremento automático de reproducciones en play_events
create or replace function public.increment_song_play_count()
returns trigger as $$
begin
    update public.songs
    set play_count = play_count + 1
    where id = new.song_id;
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_increment_play on public.play_events;
create trigger trigger_increment_play
    after insert on public.play_events
    for each row execute function public.increment_song_play_count();

-- ======================================================================
-- FUNCIONES RPC EN SERVIDOR (Requerimiento estricto)
-- ======================================================================

-- 1. band_aggregated_stats(p_band uuid): Métricas calculadas en PostgreSQL
create or replace function public.band_aggregated_stats(p_band uuid)
returns jsonb as $$
declare
    v_total_plays bigint;
    v_total_seconds bigint;
    v_total_minutes bigint;
    v_top_songs jsonb;
    v_last_7_days_plays bigint;
    v_result jsonb;
begin
    -- Total reproducciones de la banda
    select count(*), coalesce(sum(seconds_listened), 0)
    into v_total_plays, v_total_seconds
    from public.play_events
    where band_id = p_band;

    v_total_minutes := floor(v_total_seconds / 60);

    -- Reproducciones en los últimos 7 días
    select count(*)
    into v_last_7_days_plays
    from public.play_events
    where band_id = p_band
      and created_at >= (timezone('utc'::text, now()) - interval '7 days');

    -- Top 5 canciones
    select coalesce(jsonb_agg(sub), '[]'::jsonb)
    into v_top_songs
    from (
        select s.id, s.title, s.duration_s, s.play_count, count(pe.id) as recent_plays
        from public.songs s
        left join public.play_events pe on s.id = pe.song_id
        where s.band_id = p_band and s.hidden = false
        group by s.id, s.title, s.duration_s, s.play_count
        order by s.play_count desc, recent_plays desc
        limit 5
    ) sub;

    v_result := jsonb_build_object(
        'band_id', p_band,
        'total_plays', v_total_plays,
        'total_minutes', v_total_minutes,
        'last_7_days_plays', v_last_7_days_plays,
        'top_songs', v_top_songs
    );

    return v_result;
end;
$$ language plpgsql stable security definer;

-- 2. band_top_fans(p_band uuid, p_days int default 30): Top 10 fans con Opt-in de privacidad
create or replace function public.band_top_fans(p_band uuid, p_days int default 30)
returns table (
    rank int,
    user_id uuid,
    display_name text,
    avatar_url text,
    minutes_listened bigint,
    is_public boolean
) as $$
begin
    return query
    with fan_aggregates as (
        select
            pe.user_id as f_user_id,
            coalesce(sum(pe.seconds_listened), 0) as total_seconds
        from public.play_events pe
        where pe.band_id = p_band
          and pe.user_id is not null
          and pe.created_at >= (timezone('utc'::text, now()) - (p_days || ' days')::interval)
        group by pe.user_id
    )
    select
        (row_number() over (order by fa.total_seconds desc))::int as rank,
        fa.f_user_id as user_id,
        case
            when p.is_public_profile = true then p.display_name
            else 'Fan anónimo'
        end as display_name,
        case
            when p.is_public_profile = true then p.avatar_url
            else null
        end as avatar_url,
        (fa.total_seconds / 60)::bigint as minutes_listened,
        coalesce(p.is_public_profile, false) as is_public
    from fan_aggregates fa
    left join public.profiles p on fa.f_user_id = p.id
    order by fa.total_seconds desc
    limit 10;
end;
$$ language plpgsql stable security definer;

-- ======================================================================
-- PUBLICACIÓN REALTIME PARA STREAMING DE DONACIONES Y EVENTOS
-- ======================================================================
alter publication supabase_realtime add table public.donations;
alter publication supabase_realtime add table public.play_events;

