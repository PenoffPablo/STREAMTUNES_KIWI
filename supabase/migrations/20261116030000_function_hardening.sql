-- ----------------------------------------------------------------------
-- Endurecimiento de funciones SECURITY DEFINER
--
-- En Postgres toda función nueva es ejecutable por PUBLIC, y Supabase además
-- las expone por la API REST (/rest/v1/rpc/<nombre>). Se quita el permiso a
-- las que no deben llamarse desde la app.
--
-- NO se tocan is_admin / is_band_member / is_band_owner: las evalúan las
-- políticas RLS con el rol del usuario y necesitan seguir siendo ejecutables.
-- ----------------------------------------------------------------------

-- 1. Funciones de trigger y de evento: solo las invoca la base. Postgres no
--    verifica EXECUTE al disparar un trigger, así que siguen funcionando.
revoke execute on function public.accumulate_donation()          from public, anon, authenticated;
revoke execute on function public.add_creator_as_owner()         from public, anon, authenticated;
revoke execute on function public.auto_hide_reported_song()      from public, anon, authenticated;
revoke execute on function public.bump_play_count()              from public, anon, authenticated;
revoke execute on function public.enforce_album_limit()          from public, anon, authenticated;
revoke execute on function public.enforce_song_album_same_band() from public, anon, authenticated;
revoke execute on function public.enforce_song_limit()           from public, anon, authenticated;
revoke execute on function public.handle_new_user()              from public, anon, authenticated;
revoke execute on function public.validate_donation()            from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()              from public, anon, authenticated;

-- 2. Recalcular estadísticas diarias: tarea de mantenimiento (cron / service role),
--    no de usuarios.
revoke execute on function public.refresh_band_daily_stats(date) from public, anon, authenticated;

-- 3. Métricas del panel: solo miembros de la banda o moderadores.
create or replace function public.band_aggregated_stats(p_band uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
    v_total_plays int := 0;
    v_total_seconds int := 0;
    v_recent_plays int := 0;
    v_top_songs jsonb := '[]'::jsonb;
begin
    if not (public.is_band_member(p_band) or public.is_admin()) then
        raise exception 'Solo los miembros de la banda pueden ver sus métricas.'
            using errcode = '42501';
    end if;

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

revoke execute on function public.band_aggregated_stats(uuid) from public, anon;
grant execute on function public.band_aggregated_stats(uuid) to authenticated;

-- 4. Top fans (perfil público de la banda). Antes partía de TODOS los perfiles
--    con LEFT JOIN: listaba como "top fans" a usuarios que nunca escucharon a
--    la banda (0 minutos) y exponía el user_id de perfiles privados.
--    Ahora: solo quienes escucharon, y sin user_id ni avatar si el perfil es privado.
create or replace function public.band_top_fans(p_band uuid, p_days integer default 30)
returns table(rank integer, user_id uuid, display_name text, avatar_url text, minutes_listened integer, is_public boolean)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
    return query
    select
        (row_number() over (order by sum(pe.seconds_listened) desc))::int as rank,
        case when p.is_public_profile then p.id else null end as user_id,
        case when p.is_public_profile then p.display_name else 'Fan anónimo' end as display_name,
        case when p.is_public_profile then p.avatar_url else null end as avatar_url,
        round(sum(pe.seconds_listened) / 60.0)::int as minutes_listened,
        p.is_public_profile as is_public
    from public.play_events pe
    join public.profiles p on p.id = pe.user_id
    where pe.band_id = p_band
      and pe.created_at >= now() - make_interval(days => p_days)
    group by p.id, p.display_name, p.avatar_url, p.is_public_profile
    having sum(pe.seconds_listened) > 0
    order by sum(pe.seconds_listened) desc
    limit 10;
end;
$$;
