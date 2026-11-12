import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/album.dart';
import 'package:streamtunes/models/song.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SongsRepository {
  Future<List<Song>> getLatestSongs({int limit = 20, String? genre, String? query});
  Future<List<Song>> getSongsByBand(String bandId);
  Future<Song?> getSongById(String id);
  Future<Song> uploadSong(Song song);
  Future<int> getBandSongCount(String bandId);
  Future<int> getBandAlbumCount(String bandId);
  Future<List<Album>> getBandAlbums(String bandId);
  Future<Album> createAlbum(Album album);
  Future<void> logPlayEvent(String songId, String bandId, String? userId, int secondsListened);
  Future<bool> isSha256Duplicate(String sha256);
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeSongsRepository implements SongsRepository {
  final List<Song> _songs = [
    Song(
      id: 'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      albumId: 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1',
      title: 'Noches en el Andén',
      genre: 'Rock',
      audioPath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
      durationSeconds: 210,
      lyricsLrc: '[00:00.00] (Introducción con bajo y batería distorsionada)\n[00:15.20] El último tren se va perdiendo en la niebla\n[00:22.50] Luces de neón parpadean en la estación\n[00:30.10] No tengo boleto pero tengo tu canción\n[00:38.00] Y las pisadas resuenan en el andén vacío\n[00:46.40] (Solo de guitarra saturada)\n[01:02.10] Dicen que el tiempo cura lo que el viento quiebra\n[01:10.00] Pero este acorde sigue ardiendo en mi pecho\n[01:18.30] Noches en el andén, promesas de metal\n[01:26.50] El eco del underground nunca va a callar',
      audioSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      waveformPeaks: const [12, 28, 45, 60, 85, 92, 70, 50, 65, 88, 95, 100, 80, 60, 45, 75, 90, 85, 65, 55, 40, 70, 85, 95, 90, 75, 60, 80, 95, 88, 70, 50, 35, 60, 75, 90, 85, 60, 40, 20],
      playCount: 142,
      hidden: false,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      bandName: 'Los Fuzzers',
    ),
    Song(
      id: 'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      albumId: 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1',
      title: 'Vapor y Distorsión',
      genre: 'Rock',
      audioPath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745',
      durationSeconds: 185,
      lyricsLrc: '[00:00.00] (Acople de amplificador valvular)\n[00:10.00] Respiro el humo denso del sótano\n[00:18.40] Cables enredados sobre el piso de madera\n[00:26.00] Subí el volumen hasta que vibre el alma\n[00:34.50] Vapor y distorsión, nuestra trinchera',
      audioSha256: 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
      waveformPeaks: const [20, 35, 55, 70, 80, 85, 90, 95, 85, 75, 65, 55, 60, 75, 85, 95, 100, 90, 80, 70, 60, 50, 65, 80, 90, 85, 75, 65, 70, 85, 90, 95, 80, 65, 50, 40, 55, 70, 60, 30],
      playCount: 98,
      hidden: false,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      bandName: 'Los Fuzzers',
    ),
    Song(
      id: 'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      title: 'Cintas de Caset Viejas',
      genre: 'Indie',
      audioPath: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819',
      durationSeconds: 195,
      lyricsLrc: '[00:00.00] (Siseo suave de cinta magnética)\n[00:12.30] Grabado en una sola toma sin retorno\n[00:20.10] Si pifiamos una nota se queda igual\n[00:28.00] La belleza de lo roto y lo sincero\n[00:36.50] No necesita ningún pulido digital',
      audioSha256: '88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589',
      waveformPeaks: const [10, 20, 30, 45, 60, 75, 80, 70, 60, 50, 45, 55, 70, 80, 85, 75, 65, 50, 40, 50, 65, 75, 80, 70, 60, 50, 40, 55, 70, 80, 75, 60, 45, 35, 45, 55, 65, 50, 35, 15],
      playCount: 64,
      hidden: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      bandName: 'Los Fuzzers',
    ),
  ];

  final List<Album> _albums = [
    Album(
      id: 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      title: 'Frecuencias Sucias',
      releaseYear: 2026,
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  @override
  Future<List<Song>> getLatestSongs({int limit = 20, String? genre, String? query}) async {
    return _songs.where((s) {
      if (s.hidden) return false;
      if (genre != null && genre != 'Todos' && s.genre.toLowerCase() != genre.toLowerCase()) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final matches = s.title.toLowerCase().contains(q) ||
            (s.bandName?.toLowerCase().contains(q) ?? false) ||
            s.genre.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).take(limit).toList();
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    return _songs.where((s) => s.bandId == bandId && !s.hidden).toList();
  }

  @override
  Future<Song?> getSongById(String id) async {
    try {
      return _songs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Song> uploadSong(Song song) async {
    // Validar tope de 20 canciones por banda
    final currentCount = _songs.where((s) => s.bandId == song.bandId).length;
    if (currentCount >= 20) {
      throw Exception('Cupo alcanzado: La banda ya tiene 20 canciones subidas (máximo permitido: 20)');
    }

    // Validar SHA-256 duplicado
    if (await isSha256Duplicate(song.audioSha256)) {
      throw Exception('El archivo de audio ya fue subido anteriormente (SHA-256 duplicado).');
    }

    final newSong = song.copyWith(
      id: song.id.isNotEmpty ? song.id : 'song-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
    _songs.insert(0, newSong);
    return newSong;
  }

  @override
  Future<int> getBandSongCount(String bandId) async {
    return _songs.where((s) => s.bandId == bandId).length;
  }

  @override
  Future<int> getBandAlbumCount(String bandId) async {
    return _albums.where((a) => a.bandId == bandId).length;
  }

  @override
  Future<List<Album>> getBandAlbums(String bandId) async {
    return _albums.where((a) => a.bandId == bandId).toList();
  }

  @override
  Future<Album> createAlbum(Album album) async {
    final currentCount = _albums.where((a) => a.bandId == album.bandId).length;
    if (currentCount >= 2) {
      throw Exception('Cupo alcanzado: La banda ya tiene 2 álbumes (máximo permitido: 2)');
    }
    final newAlbum = album.copyWith(
      id: album.id.isNotEmpty ? album.id : 'album-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
    _albums.add(newAlbum);
    return newAlbum;
  }

  @override
  Future<void> logPlayEvent(String songId, String bandId, String? userId, int secondsListened) async {
    final idx = _songs.indexWhere((s) => s.id == songId);
    if (idx != -1) {
      _songs[idx] = _songs[idx].copyWith(playCount: _songs[idx].playCount + 1);
    }
  }

  @override
  Future<bool> isSha256Duplicate(String sha256) async {
    if (sha256.isEmpty) return false;
    return _songs.any((s) => s.audioSha256 == sha256);
  }
}

//// Implementación real conectada a Supabase
class SupabaseSongsRepository implements SongsRepository {
  final SupabaseClient _client;

  SupabaseSongsRepository(this._client);

  @override
  Future<List<Song>> getLatestSongs({int limit = 20, String? genre, String? query}) async {
    var req = _client.from('songs').select('*, bands(name)').eq('hidden', false);
    if (genre != null && genre != 'Todos') {
      req = req.ilike('genre', genre);
    }
    if (query != null && query.isNotEmpty) {
      req = req.or('title.ilike.%$query%,genre.ilike.%$query%');
    }

    final res = await req.order('created_at', ascending: false).limit(limit);
    return (res as List).map((json) {
      final bandName = json['bands']?['name'] as String?;
      return Song.fromJson(json, bandName: bandName);
    }).toList();
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    final res = await _client
        .from('songs')
        .select('*, bands(name)')
        .eq('band_id', bandId)
        .eq('hidden', false)
        .order('play_count', ascending: false);
    return (res as List).map((json) {
      final bandName = json['bands']?['name'] as String?;
      return Song.fromJson(json, bandName: bandName);
    }).toList();
  }

  @override
  Future<Song?> getSongById(String id) async {
    try {
      final res = await _client
          .from('songs')
          .select('*, bands(name)')
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      final bandName = res['bands']?['name'] as String?;
      return Song.fromJson(res, bandName: bandName);
    } catch (e) {
      debugPrint('[SupabaseSongsRepository] Error getSongById: $e');
      return null;
    }
  }

  @override
  Future<Song> uploadSong(Song song) async {
    String remoteAudioPath = song.audioPath;

    // 1. Si el audio es un archivo local del dispositivo, subirlo al bucket 'audio'
    try {
      final file = File(song.audioPath);
      if (file.existsSync()) {
        final ext = song.audioPath.split('.').last.toLowerCase();
        final fileName = '${song.bandId}/${DateTime.now().millisecondsSinceEpoch}_${song.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.$ext';
        await _client.storage.from('audio').upload(
          fileName,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
        remoteAudioPath = fileName;
      }
    } catch (e) {
      debugPrint('[SupabaseSongsRepository] Error subiendo archivo a Storage: $e');
    }

    // 2. Si la portada es un archivo local, subirla al bucket 'covers'
    String? remoteCoverUrl = song.coverUrl;
    if (song.coverUrl != null && !song.coverUrl!.startsWith('http')) {
      try {
        final coverFile = File(song.coverUrl!);
        if (coverFile.existsSync()) {
          final fileName = '${song.bandId}/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
          await _client.storage.from('covers').upload(
            fileName,
            coverFile,
            fileOptions: const FileOptions(upsert: true),
          );
          remoteCoverUrl = _client.storage.from('covers').getPublicUrl(fileName);
        }
      } catch (e) {
        debugPrint('[SupabaseSongsRepository] Error subiendo portada a Storage: $e');
      }
    }

    // 3. Insertar registro en PostgreSQL
    final payload = song.copyWith(
      audioPath: remoteAudioPath,
      coverUrl: remoteCoverUrl,
    ).toJson()..remove('id');

    final res = await _client.from('songs').insert(payload).select('*, bands(name)').single();
    final bandName = res['bands']?['name'] as String?;
    return Song.fromJson(res, bandName: bandName);
  }

  @override
  Future<int> getBandSongCount(String bandId) async {
    final res = await _client
        .from('songs')
        .select('id')
        .eq('band_id', bandId);
    return (res as List).length;
  }

  @override
  Future<int> getBandAlbumCount(String bandId) async {
    final res = await _client
        .from('albums')
        .select('id')
        .eq('band_id', bandId);
    return (res as List).length;
  }

  @override
  Future<List<Album>> getBandAlbums(String bandId) async {
    final res = await _client
        .from('albums')
        .select()
        .eq('band_id', bandId)
        .order('created_at', ascending: false);
    return (res as List).map((json) => Album.fromJson(json)).toList();
  }

  @override
  Future<Album> createAlbum(Album album) async {
    final payload = album.toJson()..remove('id');
    final res = await _client.from('albums').insert(payload).select().single();
    return Album.fromJson(res);
  }

  @override
  Future<void> logPlayEvent(String songId, String bandId, String? userId, int secondsListened) async {
    try {
      await _client.from('play_events').insert({
        'song_id': songId,
        'band_id': bandId,
        'user_id': userId,
        'seconds_listened': secondsListened,
      });
    } catch (e) {
      debugPrint('[SupabaseSongsRepository] Error registrando play event: $e');
    }
  }

  @override
  Future<bool> isSha256Duplicate(String sha256) async {
    final res = await _client
        .from('songs')
        .select('id')
        .eq('audio_sha256', sha256)
        .maybeSingle();
    return res != null;
  }
}

