-- ======================================================================
-- STREAMTUNES - SEED DATA
-- Datos de prueba para desarrollo y demostración offline/online
-- ======================================================================

-- 1. IDs Deterministas para pruebas
do $$
declare
    v_admin_id uuid := '11111111-1111-1111-1111-111111111111';
    v_artist_id uuid := '22222222-2222-2222-2222-222222222222';
    v_fan1_id uuid := '33333333-3333-3333-3333-333333333333';
    v_fan2_id uuid := '44444444-4444-4444-4444-444444444444';
    v_band1_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    v_band2_id uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    v_album1_id uuid := 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1';
    v_song1_id uuid := 'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1';
    v_song2_id uuid := 'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2';
    v_song3_id uuid := 'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3';
begin
    -- Perfiles
    insert into public.profiles (id, display_name, avatar_url, is_public_profile, is_anonymous)
    values
        (v_admin_id, 'Lucía Colectivo (Admin)', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb', true, false),
        (v_artist_id, 'Martín Fuzz', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d', true, false),
        (v_fan1_id, 'Valeria Indie', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330', true, false), -- Public opt-in
        (v_fan2_id, 'Sombra Nocturna', null, false, false) -- Private opt-in (masked in rankings)
    on conflict (id) do nothing;

    -- Admin
    insert into public.app_admins (user_id)
    values (v_admin_id)
    on conflict (user_id) do nothing;

    -- Banda 1: Los Fuzzers (Aprobada)
    insert into public.bands (id, slug, name, bio, genre, location, cover_url, merch_url, social_links, donation_goal, donations_collected, status, created_by)
    values (
        v_band1_id,
        'los-fuzzers',
        'Los Fuzzers',
        'Rock de garage, fuzz distorsionado y letras de medianoche desde el conurbano.',
        'Rock',
        'Buenos Aires, AR',
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
        'https://merch.losfuzzers.com',
        '{"instagram": "https://instagram.com/losfuzzers", "bandcamp": "https://losfuzzers.bandcamp.com"}'::jsonb,
        45000.00,
        18500.00,
        'approved',
        v_artist_id
    ) on conflict (id) do nothing;

    -- Banda 2: Nebulosa Subterránea (Pendiente de aprobación para moderación)
    insert into public.bands (id, slug, name, bio, genre, location, cover_url, merch_url, social_links, donation_goal, donations_collected, status, created_by)
    values (
        v_band2_id,
        'nebulosa-subterranea',
        'Nebulosa Subterránea',
        'Post-punk atmosférico grabado en cassettes vírgenes de 1994.',
        'Indie',
        'La Plata, AR',
        'https://images.unsplash.com/photo-1465847899084-d164df4dedc6',
        null,
        '{"bandcamp": "https://nebulosasub.bandcamp.com"}'::jsonb,
        30000.00,
        0.00,
        'pending',
        v_artist_id
    ) on conflict (id) do nothing;

    -- Membresía
    insert into public.band_members (band_id, user_id, role)
    values (v_band1_id, v_artist_id, 'owner')
    on conflict do nothing;

    -- Álbum 1
    insert into public.albums (id, band_id, title, release_year, cover_url)
    values (v_album1_id, v_band1_id, 'Frecuencias Sucias', 2026, 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4')
    on conflict (id) do nothing;

    -- Canción 1
    insert into public.songs (
        id, band_id, album_id, title, genre, audio_path, cover_url,
        duration_s, lyrics_lrc, audio_sha256, waveform_peaks, play_count, hidden
    ) values (
        v_song1_id,
        v_band1_id,
        v_album1_id,
        'Noches en el Andén',
        'Rock',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
        210,
        '[00:00.00] (Introducción con bajo y batería distorsionada)\n[00:15.20] El último tren se va perdiendo en la niebla\n[00:22.50] Luces de neón parpadean en la estación\n[00:30.10] No tengo boleto pero tengo tu canción\n[00:38.00] Y las pisadas resuenan en el andén vacío\n[00:46.40] (Solo de guitarra saturada)\n[01:02.10] Dicen que el tiempo cura lo que el viento quiebra\n[01:10.00] Pero este acorde sigue ardiendo en mi pecho\n[01:18.30] Noches en el andén, promesas de metal\n[01:26.50] El eco del underground nunca va a callar',
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        '[12, 28, 45, 60, 85, 92, 70, 50, 65, 88, 95, 100, 80, 60, 45, 75, 90, 85, 65, 55, 40, 70, 85, 95, 90, 75, 60, 80, 95, 88, 70, 50, 35, 60, 75, 90, 85, 60, 40, 20]'::jsonb,
        142,
        false
    ) on conflict (id) do nothing;

    -- Canción 2
    insert into public.songs (
        id, band_id, album_id, title, genre, audio_path, cover_url,
        duration_s, lyrics_lrc, audio_sha256, waveform_peaks, play_count, hidden
    ) values (
        v_song2_id,
        v_band1_id,
        v_album1_id,
        'Vapor y Distorsión',
        'Rock',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745',
        185,
        '[00:00.00] (Acople de amplificador valvular)\n[00:10.00] Respiro el humo denso del sótano\n[00:18.40] Cables enredados sobre el piso de madera\n[00:26.00] Subí el volumen hasta que vibre el alma\n[00:34.50] Vapor y distorsión, nuestra trinchera',
        'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
        '[20, 35, 55, 70, 80, 85, 90, 95, 85, 75, 65, 55, 60, 75, 85, 95, 100, 90, 80, 70, 60, 50, 65, 80, 90, 85, 75, 65, 70, 85, 90, 95, 80, 65, 50, 40, 55, 70, 60, 30]'::jsonb,
        98,
        false
    ) on conflict (id) do nothing;

    -- Canción 3 (Tema suelto)
    insert into public.songs (
        id, band_id, album_id, title, genre, audio_path, cover_url,
        duration_s, lyrics_lrc, audio_sha256, waveform_peaks, play_count, hidden
    ) values (
        v_song3_id,
        v_band1_id,
        null,
        'Cintas de Caset Viejas',
        'Indie',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819',
        195,
        '[00:00.00] (Siseo suave de cinta magnética)\n[00:12.30] Grabado en una sola toma sin retorno\n[00:20.10] Si pifiamos una nota se queda igual\n[00:28.00] La belleza de lo roto y lo sincero\n[00:36.50] No necesita ningún pulido digital',
        '88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589',
        '[10, 20, 30, 45, 60, 75, 80, 70, 60, 50, 45, 55, 70, 80, 85, 75, 65, 50, 40, 50, 65, 75, 80, 70, 60, 50, 40, 55, 70, 80, 75, 60, 45, 35, 45, 55, 65, 50, 35, 15]'::jsonb,
        64,
        false
    ) on conflict (id) do nothing;

    -- Fechas de Shows en Vivo
    insert into public.band_events (band_id, title, venue, city, event_date, ticket_url)
    values
        (v_band1_id, 'Ciclo Ruido Subterráneo', 'Salón Pueyrredón', 'Buenos Aires', now() + interval '5 days', 'https://entradas.salonpueyrredon.com/ruido'),
        (v_band1_id, 'Festival Fuzz del Conurbano', 'El Galpón de Hurlingham', 'Hurlingham', now() + interval '18 days', null)
    on conflict do nothing;

    -- Galería de Fotos
    insert into public.band_photos (band_id, photo_url, caption)
    values
        (v_band1_id, 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745', 'Sótano en San Telmo - Setiembre 2026'),
        (v_band1_id, 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a', 'Probando sonido en el festival')
    on conflict do nothing;

    -- Donaciones Transparentes
    insert into public.donations (band_id, donor_user_id, donor_name, amount_ars, message, is_anonymous, status)
    values
        (v_band1_id, v_fan1_id, 'Valeria Indie', 2500.00, '¡Aguante el sonido crudo! Nos vemos el sábado.', false, 'approved'),
        (v_band1_id, v_fan2_id, 'Fan anónimo', 1000.00, 'Para las cuerdas de la viola.', true, 'approved')
    on conflict do nothing;

    -- Reproducciones simuladas (play_events) para métricas y top fans
    insert into public.play_events (song_id, band_id, user_id, seconds_listened)
    values
        (v_song1_id, v_band1_id, v_fan1_id, 210),
        (v_song1_id, v_band1_id, v_fan1_id, 180),
        (v_song2_id, v_band1_id, v_fan1_id, 185),
        (v_song1_id, v_band1_id, v_fan2_id, 150),
        (v_song2_id, v_band1_id, v_fan2_id, 170)
    on conflict do nothing;
end $$;

