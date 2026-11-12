import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/playlists_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  final PlaylistsRepository playlistsRepo;
  final BandsRepository bandsRepo;

  List<Playlist> _playlists = [];
  List<Band> _followedBands = [];
  final Map<String, List<Song>> _playlistSongsCache = {};
  bool _isLoading = false;
  String? _errorMessage;

  LibraryViewModel({
    required this.playlistsRepo,
    required this.bandsRepo,
  });

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Band> get followedBands => List.unmodifiable(_followedBands);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLibrary(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final playlistsFuture = playlistsRepo.getUserPlaylists(userId);
      final followedFuture = bandsRepo.getFollowedBands(userId);

      final results = await Future.wait([playlistsFuture, followedFuture]);
      _playlists = results[0] as List<Playlist>;
      _followedBands = results[1] as List<Band>;
    } catch (e) {
      _errorMessage = 'Error cargando biblioteca: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Playlist?> createPlaylist(String userId, String title) async {
    try {
      final pl = await playlistsRepo.createPlaylist(userId, title);
      _playlists.insert(0, pl);
      notifyListeners();
      return pl;
    } catch (e) {
      _errorMessage = 'Error creando playlist: $e';
      notifyListeners();
      return null;
    }
  }

  /// Acción directa para sumar un tema a una playlist desde cualquier pantalla
  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    try {
      await playlistsRepo.addSongToPlaylist(playlistId, songId);
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final currentSongs = List<String>.from(_playlists[idx].songIds);
        if (!currentSongs.contains(songId)) {
          currentSongs.add(songId);
          _playlists[idx] = _playlists[idx].copyWith(songIds: currentSongs);
          notifyListeners();
        }
      }
      return true;
    } catch (e) {
      _errorMessage = 'Error sumando canción a playlist: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    if (_playlistSongsCache.containsKey(playlistId)) {
      return _playlistSongsCache[playlistId]!;
    }
    final songs = await playlistsRepo.getPlaylistSongs(playlistId);
    _playlistSongsCache[playlistId] = songs;
    return songs;
  }
}
