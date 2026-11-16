import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository.dart';

/// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakePlaylistsRepository implements PlaylistsRepository {
  final List<Playlist> _playlists = [
    Playlist(
      id: 'pl-1',
      userId: '33333333-3333-3333-3333-333333333333',
      title: 'Favoritos de Sótano',
      songIds: [
        'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1',
        'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2',
      ],
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
      final currentSongs = List<String>.from(_playlists[idx].songIds)
        ..remove(songId);
      _playlists[idx] = _playlists[idx].copyWith(songIds: currentSongs);
    }
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final pl = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => Playlist(
        id: playlistId,
        userId: '',
        title: '',
        songIds: [],
        createdAt: DateTime.now(),
      ),
    );
    return pl.songIds
        .map<Song>(
          (id) => Song(
            id: id,
            bandId: 'fake-band',
            title: 'Canción ${id.substring(0, id.length > 8 ? 8 : id.length)}',
            genre: 'Rock',
            durationSeconds: 180,
            audioPath: 'https://example.com/audio.mp3',
            audioSha256: 'fake-sha256-$id',
            createdAt: DateTime.now(),
          ),
        )
        .toList();
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
  }
}
