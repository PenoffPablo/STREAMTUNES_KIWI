import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabasePlaylistsRepository implements PlaylistsRepository {
  final SupabaseClient _client;

  SupabasePlaylistsRepository(this._client);

  @override
  Future<List<Playlist>> getUserPlaylists(String userId) async {
    try {
      final res =
          await (_client
                  .from('playlists')
                  .select('*, playlist_songs(song_id, position)')
                  .eq('user_id', userId)
                  .order('created_at', ascending: false))
              .withNetworkTimeout();

      return (res as List).map((json) {
        final songs =
            (json['playlist_songs'] as List?)
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
    final res =
        await (_client
                .from('playlists')
                .insert({
                  'user_id': userId,
                  'title': title,
                  'name': title,
                  'is_public': true,
                })
                .select()
                .single())
            .withNetworkTimeout();
    return Playlist.fromJson(res);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    int nextPos = 1;
    try {
      final existing =
          await (_client
                  .from('playlist_songs')
                  .select('song_id')
                  .eq('playlist_id', playlistId))
              .withNetworkTimeout();
      nextPos = (existing as List).length + 1;
    } catch (_) {}

    await (_client.from('playlist_songs').upsert({
      'playlist_id': playlistId,
      'song_id': songId,
      'position': nextPos,
    })).withNetworkTimeout();
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await (_client
            .from('playlist_songs')
            .delete()
            .eq('playlist_id', playlistId)
            .eq('song_id', songId))
        .withNetworkTimeout();
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    try {
      final res =
          await (_client
                  .from('playlist_songs')
                  .select('songs(*, bands(name))')
                  .eq('playlist_id', playlistId)
                  .order('position', ascending: true))
              .withNetworkTimeout();

      return (res as List).where((row) => row['songs'] != null).map((row) {
        final songJson = row['songs'] as Map<String, dynamic>;
        final bandName = songJson['bands']?['name'] as String?;
        return Song.fromJson(songJson, bandName: bandName);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await (_client.from('playlists').delete().eq('id', playlistId))
        .withNetworkTimeout();
  }
}
