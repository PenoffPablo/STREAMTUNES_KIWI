import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';

abstract class PlaylistsRepository {
  Future<List<Playlist>> getUserPlaylists(String userId);
  Future<Playlist> createPlaylist(String userId, String title);
  Future<void> addSongToPlaylist(String playlistId, String songId);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  Future<List<Song>> getPlaylistSongs(String playlistId);
  Future<void> deletePlaylist(String playlistId);
}
