import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/models/song.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PlaylistsRepository {
  Future<List<Playlist>> getUserPlaylists(String userId);
  Future<Playlist> createPlaylist(String userId, String title);
  Future<void> addSongToPlaylist(String playlistId, String songId);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  Future<List<Song>> getPlaylistSongs(String playlistId);
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakePlaylistsRepository implements PlaylistsRepository {
  final List<Playlist> _playlists = [
    Playlist(
      id: 'pl-1',
      userId: '33333333-3333-3333-3333-333333333333',
      title: 'Favoritos de Sótano',
      songIds: ['d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1', 'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2'],
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  Future<List<Playlist>> getUserPlaylists(String userId) async {
    return _playlists.where((p) => p.userId == userId).toList();
  }

  @override
  Future<Playlist> createPlaylist(String userId, String title) async {
    final newPl = Playlist(
      id: 'pl-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title,
      songIds: [],
      createdAt: DateTime.now(),
    );
    _playlists.add(newPl);
    return newPl;
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final currentSongs = List<String>.from(_playlists[idx].songIds);
      if (!currentSongs.contains(songId)) {
        currentSongs.add(songId);
        _playlists[idx] = _playlists[idx].copyWith(songIds: currentSongs);
      }
    }
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final currentSongs = List<String>.from(_playlists[idx].songIds)..remove(songId);
      _playlists[idx] = _playlists[idx].copyWith(songIds: currentSongs);
    }
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    return [];
  }
}

//// Implementación real conectada a Supabase
class SupabasePlaylistsRepository implements PlaylistsRepository {
  final SupabaseClient _client;

  SupabasePlaylistsRepository(this._client);

  @override
  Future<List<Playlist>> getUserPlaylists(String userId) async {
    try {
      final res = await _client
          .from('playlists')
          .select('*, playlist_songs(song_id, position)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (res as List).map((json) {
        final songs = (json['playlist_songs'] as List?)
                ?.map((e) => (e['song_id'] ?? e) as String)
                .toList() ??
            [];
        return Playlist.fromJson(json, songIds: songs);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Playlist> createPlaylist(String userId, String title) async {
    final res = await _client
        .from('playlists')
        .insert({
          'user_id': userId,
          'title': title,
          'name': title,
          'is_public': true,
        })
        .select()
        .single();
    return Playlist.fromJson(res);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    int nextPos = 1;
    try {
      final existing = await _client
          .from('playlist_songs')
          .select('song_id')
          .eq('playlist_id', playlistId);
      nextPos = (existing as List).length + 1;
    } catch (_) {}

    await _client.from('playlist_songs').upsert({
      'playlist_id': playlistId,
      'song_id': songId,
      'position': nextPos,
    });
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _client
        .from('playlist_songs')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('song_id', songId);
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    try {
      final res = await _client
          .from('playlist_songs')
          .select('songs(*, bands(name))')
          .eq('playlist_id', playlistId)
          .order('position', ascending: true);

      return (res as List)
          .where((row) => row['songs'] != null)
          .map((row) {
        final songJson = row['songs'] as Map<String, dynamic>;
        final bandName = songJson['bands']?['name'] as String?;
        return Song.fromJson(songJson, bandName: bandName);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
