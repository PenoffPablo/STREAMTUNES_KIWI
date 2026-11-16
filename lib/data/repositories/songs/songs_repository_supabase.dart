import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/album.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabaseSongsRepository implements SongsRepository {
  final SupabaseClient _client;

  SupabaseSongsRepository(this._client);

  @override
  Future<List<Song>> getLatestSongs({
    int limit = 20,
    String? genre,
    String? query,
  }) async {
    var req = _client
        .from('songs')
        .select('*, bands(name)')
        .eq('hidden', false);
    if (genre != null && genre != 'Todos') {
      req = req.ilike('genre', genre);
    }
    if (query != null && query.isNotEmpty) {
      req = req.or('title.ilike.%$query%,genre.ilike.%$query%');
    }

    final res = await req.order('created_at', ascending: false).limit(limit).withNetworkTimeout();
    return (res as List).map((json) {
      final bandName = json['bands']?['name'] as String?;
      return Song.fromJson(json, bandName: bandName);
    }).toList();
  }

  @override
  Future<List<Song>> getSongsByBand(String bandId) async {
    final res =
        await (_client
                .from('songs')
                .select('*, bands(name)')
                .eq('band_id', bandId)
                .eq('hidden', false)
                .order('play_count', ascending: false))
            .withNetworkTimeout();
    return (res as List).map((json) {
      final bandName = json['bands']?['name'] as String?;
      return Song.fromJson(json, bandName: bandName);
    }).toList();
  }

  @override
  Future<Song?> getSongById(String id) async {
    try {
      final res =
          await (_client
                  .from('songs')
                  .select('*, bands(name)')
                  .eq('id', id)
                  .maybeSingle())
              .withNetworkTimeout();
      if (res == null) return null;
      final bandName = res['bands']?['name'] as String?;
      return Song.fromJson(res, bandName: bandName);
    } catch (e) {
      debugPrint('[SupabaseSongsRepository] Error getSongById: $e');
      return null;
    }
  }

  @override
  Future<Song> uploadSong(
    Song song, {
    Uint8List? audioBytes,
    String? audioExtension,
  }) async {
    final safeTitle = song.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Subir el audio al bucket 'audio'. Si falla, se propaga el error:
    //    NO se inserta la canción con una ruta local que nadie más puede reproducir.
    final String remoteAudioPath;
    final localAudio = song.audioPath.isNotEmpty && !kIsWeb
        ? File(song.audioPath)
        : null;
    if (localAudio != null && localAudio.existsSync()) {
      final ext = song.audioPath.split('.').last.toLowerCase();
      remoteAudioPath = '${song.bandId}/${stamp}_$safeTitle.$ext';
      await _client.storage
          .from('audio')
          .upload(
            remoteAudioPath,
            localAudio,
            fileOptions: const FileOptions(upsert: true),
          );
    } else if (audioBytes != null && audioBytes.isNotEmpty) {
      remoteAudioPath =
          '${song.bandId}/${stamp}_$safeTitle.${audioExtension ?? 'mp3'}';
      await _client.storage
          .from('audio')
          .uploadBinary(
            remoteAudioPath,
            audioBytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } else if (song.audioPath.startsWith('http')) {
      remoteAudioPath = song.audioPath; // ya está alojado remotamente
    } else {
      throw Exception('No se encontró el archivo de audio para subir.');
    }

    // 2. Portada local -> bucket 'covers'. Es opcional: si falla, se publica sin portada
    //    (null) en lugar de guardar una ruta local inválida.
    String? remoteCoverUrl = song.coverUrl;
    if (song.coverUrl != null && !song.coverUrl!.startsWith('http')) {
      remoteCoverUrl = null;
      try {
        final coverFile = File(song.coverUrl!);
        if (!kIsWeb && coverFile.existsSync()) {
          final fileName = '${song.bandId}/${stamp}_cover.jpg';
          await _client.storage
              .from('covers')
              .upload(
                fileName,
                coverFile,
                fileOptions: const FileOptions(upsert: true),
              );
          remoteCoverUrl = _client.storage
              .from('covers')
              .getPublicUrl(fileName);
        }
      } catch (e) {
        debugPrint(
          '[SupabaseSongsRepository] Portada no subida, se publica sin portada: $e',
        );
      }
    }

    // 3. Insertar registro en PostgreSQL
    final payload =
        song
            .copyWith(audioPath: remoteAudioPath, coverUrl: remoteCoverUrl)
            .toJson()
          ..remove('id');

    final res =
        await (_client
                .from('songs')
                .insert(payload)
                .select('*, bands(name)')
                .single())
            .withNetworkTimeout();
    final bandName = res['bands']?['name'] as String?;
    return Song.fromJson(res, bandName: bandName);
  }

  @override
  Future<int> getBandSongCount(String bandId) async {
    final res = await (_client.from('songs').select('id').eq('band_id', bandId))
        .withNetworkTimeout();
    return (res as List).length;
  }

  @override
  Future<int> getBandAlbumCount(String bandId) async {
    final res =
        await (_client.from('albums').select('id').eq('band_id', bandId))
            .withNetworkTimeout();
    return (res as List).length;
  }

  @override
  Future<List<Album>> getBandAlbums(String bandId) async {
    final res =
        await (_client
                .from('albums')
                .select()
                .eq('band_id', bandId)
                .order('created_at', ascending: false))
            .withNetworkTimeout();
    return (res as List).map((json) => Album.fromJson(json)).toList();
  }

  @override
  Future<Album> createAlbum(Album album) async {
    final payload = album.toJson()..remove('id');
    final res = await (_client.from('albums').insert(payload).select().single())
        .withNetworkTimeout();
    return Album.fromJson(res);
  }

  @override
  Future<void> logPlayEvent(
    String songId,
    String bandId,
    String? userId,
    int secondsListened,
  ) async {
    try {
      await (_client.from('play_events').insert({
        'song_id': songId,
        'band_id': bandId,
        'user_id': userId,
        'seconds_listened': secondsListened,
      })).withNetworkTimeout();
    } catch (e) {
      debugPrint('[SupabaseSongsRepository] Error registrando play event: $e');
    }
  }

  @override
  Future<bool> isSha256Duplicate(String sha256) async {
    final res =
        await (_client
                .from('songs')
                .select('id')
                .eq('audio_sha256', sha256)
                .maybeSingle())
            .withNetworkTimeout();
    return res != null;
  }

  @override
  Future<Song> updateSong(Song song) async {
    final payload = {
      'title': song.title,
      'genre': song.genre,
      'lyrics_lrc': song.lyricsLrc,
      if (song.albumId != null) 'album_id': song.albumId,
      if (song.coverUrl != null) 'cover_url': song.coverUrl,
    };
    final res =
        await (_client
                .from('songs')
                .update(payload)
                .eq('id', song.id)
                .select('*, bands(name)')
                .single())
            .withNetworkTimeout();
    final bandName = res['bands']?['name'] as String?;
    return Song.fromJson(res, bandName: bandName);
  }

  @override
  Future<void> deleteSong(String songId) async {
    await (_client.from('songs').delete().eq('id', songId))
        .withNetworkTimeout();
  }
}
