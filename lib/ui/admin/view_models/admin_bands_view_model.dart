import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_overview.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Cómo se ordena la lista de bandas.
enum BandSort {
  recent('Más recientes'),
  name('Nombre (A-Z)'),
  followers('Más seguidores'),
  songs('Más temas');

  const BandSort(this.label);
  final String label;
}

/// Panel "Bandas del colectivo": todas las bandas con filtros por estado,
/// género y texto, orden, y las acciones de moderación (aprobar, suspender,
/// reactivar). Los filtros se aplican en memoria sobre lo cargado.
class AdminBandsViewModel extends ViewModel {
  AdminBandsViewModel({required this.moderationRepo});

  final ModerationRepository moderationRepo;

  List<BandOverview> _all = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _actionError;
  String? _busyBandId;

  BandStatus? _status; // null = todas
  String? _genre; // null = todos
  String _query = '';
  BandSort _sort = BandSort.recent;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Por qué falló la última acción (aprobar/suspender/reactivar).
  String? get actionError => _actionError;
  bool isBusy(String bandId) => _busyBandId == bandId;

  BandStatus? get statusFilter => _status;
  String? get genreFilter => _genre;
  String get query => _query;
  BandSort get sort => _sort;

  int get totalCount => _all.length;
  int countFor(BandStatus status) => _all.where((b) => b.band.status == status).length;

  /// Géneros presentes en las bandas cargadas (para el filtro), ordenados.
  List<String> get genres => (_all.map((b) => b.band.genre).toSet().toList()..sort());

  bool get hasActiveFilters => _status != null || _genre != null || _query.trim().isNotEmpty;

  /// Bandas que cumplen los filtros, en el orden elegido.
  List<BandOverview> get bands {
    final q = _normalize(_query.trim());
    final list = _all.where((o) {
      final b = o.band;
      if (_status != null && b.status != _status) return false;
      if (_genre != null && b.genre != _genre) return false;
      if (q.isEmpty) return true;
      return [b.name, b.location ?? '', o.ownerName ?? '', b.slug].any((t) => _normalize(t).contains(q));
    }).toList();

    switch (_sort) {
      case BandSort.recent:
        list.sort((a, b) => b.band.createdAt.compareTo(a.band.createdAt));
      case BandSort.name:
        list.sort((a, b) => _normalize(a.band.name).compareTo(_normalize(b.band.name)));
      case BandSort.followers:
        list.sort((a, b) => b.band.followerCount.compareTo(a.band.followerCount));
      case BandSort.songs:
        list.sort((a, b) => b.songCount.compareTo(a.songCount));
    }
    return list;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await moderationRepo.getAllBands();
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las bandas. ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(BandStatus? status) {
    if (status == _status) return;
    _status = status;
    notifyListeners();
  }

  void setGenreFilter(String? genre) {
    if (genre == _genre) return;
    _genre = genre;
    notifyListeners();
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  void setSort(BandSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    notifyListeners();
  }

  void clearFilters() {
    _status = null;
    _genre = null;
    _query = '';
    notifyListeners();
  }

  /// Aprueba, suspende o reactiva una banda. Devuelve `true` si se guardó.
  Future<bool> setBandStatus(String bandId, BandStatus status) async {
    if (_busyBandId != null) return false;
    _busyBandId = bandId;
    _actionError = null;
    notifyListeners();
    try {
      await moderationRepo.setBandStatus(bandId, status);
      _all = [
        for (final o in _all) o.band.id == bandId ? o.copyWith(band: o.band.copyWith(status: status)) : o,
      ];
      return true;
    } catch (e) {
      _actionError = describeError(e);
      return false;
    } finally {
      _busyBandId = null;
      notifyListeners();
    }
  }

  /// Minúsculas y sin tildes, para buscar "sotano" y encontrar "Sótano".
  static String _normalize(String text) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      out.write(i == -1 ? ch : to[i]);
    }
    return out.toString();
  }
}
