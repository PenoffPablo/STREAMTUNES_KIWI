import 'dart:async';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// ViewModel del detalle de una playlist y de su hoja "Añadir canciones".
///
/// Antes este estado (`_songs`, `_isLoading`, `_errorMessage`, el filtro de
/// búsqueda) vivía en el `State` del widget y la hoja de añadir canciones leía
/// `SongsRepository` directamente desde la View.
class PlaylistDetailViewModel extends ViewModel {
  PlaylistDetailViewModel({
    required this.playlist,
    required this.library,
    required this.songsRepo,
  });

  final Playlist playlist;

  /// Estado compartido de la biblioteca: las altas/bajas pasan por acá para que
  /// la lista de playlists (contador de temas) quede sincronizada.
  final LibraryViewModel library;
  final SongsRepository songsRepo;

  List<Song> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Song> _availableSongs = [];
  bool _isLoadingAvailable = false;
  String? _availableError;
  String _availableQuery = '';

  List<Song> get songs => List.unmodifiable(_songs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _songs.isEmpty;
  int get songCount => _isLoading ? playlist.songIds.length : _songs.length;
  Set<String> get songIds => _songs.map((s) => s.id).toSet();

  bool get isLoadingAvailable => _isLoadingAvailable;
  String? get availableError => _availableError;
  String get availableQuery => _availableQuery;

  /// Catálogo filtrado por la búsqueda de la hoja "Añadir canciones".
  List<Song> get filteredAvailableSongs {
    final q = _availableQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_availableSongs);
    return _availableSongs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          (s.bandName ?? '').toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  Future<void> loadSongs({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _songs = List.of(await library.getSongsForPlaylist(playlist.id, forceRefresh: forceRefresh));
    } catch (e) {
      _errorMessage = 'Error cargando temas de la playlist: ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cola a reproducir: en orden o mezclada. `null` si la playlist está vacía.
  List<Song>? queueFor({bool shuffle = false}) {
    if (_songs.isEmpty) return null;
    return shuffle ? (List<Song>.of(_songs)..shuffle()) : List<Song>.of(_songs);
  }

  Future<bool> removeSong(Song song) async {
    final ok = await library.removeSongFromPlaylist(playlist.id, song.id);
    if (ok) {
      _songs.removeWhere((s) => s.id == song.id);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> deletePlaylist() => library.deletePlaylist(playlist.id);

  // ---- Hoja "Añadir canciones" ----

  /// Reinicia el filtro y carga el catálogo antes de abrir la hoja.
  Future<void> prepareAddSongs() {
    _availableQuery = '';
    return loadAvailableSongs();
  }

  Future<void> loadAvailableSongs() async {
    _isLoadingAvailable = true;
    _availableError = null;
    notifyListeners();
    try {
      _availableSongs = await songsRepo.getLatestSongs(limit: 50);
    } catch (e) {
      _availableError = 'Error cargando temas disponibles: ${describeError(e)}';
    } finally {
      _isLoadingAvailable = false;
      notifyListeners();
    }
  }

  void filterAvailable(String query) {
    _availableQuery = query;
    notifyListeners();
  }

  Future<bool> addSong(Song song) async {
    if (songIds.contains(song.id)) return true;
    final ok = await library.addSongToPlaylist(playlist.id, song.id);
    if (ok) {
      _songs.add(song);
      notifyListeners();
    }
    return ok;
  }
}
