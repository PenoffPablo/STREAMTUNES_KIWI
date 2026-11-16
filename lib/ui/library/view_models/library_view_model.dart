import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class LibraryViewModel extends ViewModel {
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
      final (playlists, followed) = await (
        playlistsRepo.getUserPlaylists(userId),
        bandsRepo.getFollowedBands(userId),
      ).wait;
      _playlists = playlists;
      _followedBands = followed;
    } catch (e) {
      _errorMessage = 'Error cargando biblioteca: ${describeError(e)}';
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
        }
      }
      _playlistSongsCache.remove(playlistId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error sumando canción a playlist: $e';
      notifyListeners();
      return false;
    }
  }

  /// Quitar un tema de una playlist
  Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      await playlistsRepo.removeSongFromPlaylist(playlistId, songId);
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final currentSongs = List<String>.from(_playlists[idx].songIds)..remove(songId);
        _playlists[idx] = _playlists[idx].copyWith(songIds: currentSongs);
      }
      _playlistSongsCache.remove(playlistId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error quitando canción de playlist: $e';
      notifyListeners();
      return false;
    }
  }

  /// Eliminar una playlist completa
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await playlistsRepo.deletePlaylist(playlistId);
      _playlists.removeWhere((p) => p.id == playlistId);
      _playlistSongsCache.remove(playlistId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error eliminando playlist: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<Song>> getSongsForPlaylist(String playlistId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _playlistSongsCache.containsKey(playlistId)) {
      return _playlistSongsCache[playlistId]!;
    }
    final songs = await playlistsRepo.getPlaylistSongs(playlistId);
    _playlistSongsCache[playlistId] = songs;
    return songs;
  }

  Playlist? playlistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }
}
