import 'dart:async';

import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/utils/ids.dart';
import 'package:streamtunes/utils/stream_transformers.dart';

class QrScanResult {
  final Band? band;
  final String message;
  final bool isOffline;
  final bool isSuccess;

  const QrScanResult({this.band, required this.message, required this.isOffline, required this.isSuccess});
}

class HomeViewModel extends ViewModel {
  final SongsRepository songsRepo;
  final BandsRepository bandsRepo;
  final AuthRepository authRepo;
  final PendingFollowService pendingFollowService;
  final DeviceCapabilitiesService? deviceService;

  /// Retardo del debounce de búsqueda (configurable para tests).
  final Duration searchDebounce;

  List<Song> _latestSongs = [];
  List<Band> _approvedBands = [];
  String _selectedGenre = 'Todos';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  /// Cada carga recibe un número. Si llega la respuesta de una carga vieja
  /// (porque el usuario ya cambió el filtro), se descarta: "la última gana".
  int _requestId = 0;

  final _queryController = StreamController<String>();
  StreamSubscription<String>? _querySub;

  HomeViewModel({
    required this.songsRepo,
    required this.bandsRepo,
    required this.authRepo,
    required this.pendingFollowService,
    this.deviceService,
    this.searchDebounce = const Duration(milliseconds: 350),
  });

  List<Song> get latestSongs => List.unmodifiable(_latestSongs);
  List<Band> get approvedBands => List.unmodifiable(_approvedBands);
  String get selectedGenre => _selectedGenre;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasCamera => deviceService?.hasCamera ?? false;

  static const List<String> availableGenres = [
    'Todos',
    'Rock',
    'Indie',
    'Pop',
    'Folk',
    'Hip-Hop',
    'Electrónica',
    'Jazz',
  ];

  /// Arranca el pipeline de búsqueda y la primera carga. Lo llama la View en `initState`.
  Future<void> init() {
    // Pipeline reactivo: texto -> trim -> distinct -> debounce -> cargar feed.
    _querySub ??= _queryController.stream.map((q) => q.trim()).distinct().transform(debounce(searchDebounce)).listen((
      query,
    ) {
      if (query == _searchQuery) return; // ya aplicada (por ej. por clearSearch)
      _searchQuery = query;
      loadFeed();
    });
    return loadFeed();
  }

  Future<void> loadFeed() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final genre = _selectedGenre == 'Todos' ? null : _selectedGenre;
    final query = _searchQuery.isEmpty ? null : _searchQuery;

    try {
      // Las dos consultas corren en paralelo; el record mantiene los tipos
      // (List<Song>, List<Band>) sin casteos manuales.
      final (songs, bands) = await (
        songsRepo.getLatestSongs(genre: genre, query: query),
        bandsRepo.getBands(status: BandStatus.approved, genre: genre, query: query),
      ).wait;

      if (requestId != _requestId) return; // respuesta vieja: se descarta
      _latestSongs = songs;
      _approvedBands = bands;
    } catch (e) {
      if (requestId != _requestId) return;
      _errorMessage = describeError(e);
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setGenre(String genre) {
    if (_selectedGenre == genre) return;
    _selectedGenre = genre;
    unawaited(loadFeed()); // la View no necesita esperar: el estado avisa por notifyListeners
  }

  /// Se llama en cada tecla. El stream con debounce decide cuándo consultar.
  void search(String query) {
    if (!_queryController.isClosed) _queryController.add(query);
  }

  /// Limpia la búsqueda en el acto (sin esperar el debounce).
  void clearSearch() {
    search('');
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    unawaited(loadFeed());
  }

  void resetFilters() {
    search('');
    _searchQuery = '';
    _selectedGenre = 'Todos';
    unawaited(loadFeed());
  }

  @override
  void dispose() {
    _querySub?.cancel();
    _queryController.close();
    super.dispose();
  }

  /// Procesa el escaneo de un código QR en vivo
  /// Si hay conexión -> Autentica anónimamente si no tenía sesión y sigue a la banda
  /// Si NO hay conexión (sótano) -> Encola en PendingFollowService y abre perfil si está en caché
  Future<QrScanResult> handleQrScan(String rawData, {bool simulateOffline = false}) async {
    final cleaned = rawData.trim();
    if (cleaned.isEmpty) {
      return const QrScanResult(message: 'Código QR inválido o vacío.', isOffline: false, isSuccess: false);
    }

    // Extraer slug o ID de la banda (admite streamtunes://band/slug o https://... o ID plano)
    String target = cleaned;
    if (cleaned.contains('/band/')) {
      target = cleaned.split('/band/').last.split('?').first;
    }
    target = target.replaceAll(RegExp(r'/+$'), '').trim();

    // Caso SÓTANO UNDERGROUND forzado (tests / demo): se encola y, si la banda
    // está disponible localmente, se abre su perfil. En un corte REAL no se
    // reintenta la búsqueda: sería otro timeout de red esperando en vano.
    if (simulateOffline) {
      Band? cached;
      try {
        cached = await _findBand(target);
      } catch (_) {
        cached = null;
      }
      return _queueOffline(target, band: cached);
    }

    Band? band;
    try {
      // 1. Obtener la banda. Un error acá es de red (el repositorio devuelve
      //    null solo cuando la banda no existe): se encola para más tarde.
      band = await _findBand(target);
    } catch (_) {
      return _queueOffline(target);
    }

    try {
      if (band == null) {
        return const QrScanResult(
          message: 'Banda no encontrada en el colectivo StreamTunes.',
          isOffline: false,
          isSuccess: false,
        );
      }

      // 2. Si el fan no tiene sesión, intentar sesión anónima si está habilitada
      AppUser? user = authRepo.currentUser;
      if (user == null) {
        try {
          user = await authRepo.signInAnonymously();
        } catch (_) {
          // Si el proveedor anónimo de Auth no está habilitado, continuar
        }
      }

      // 3. Registrar el seguimiento si tenemos ID de usuario. Si falla por red,
      //    se encola el ID (ya lo conocemos) para sincronizar al volver la señal.
      if (user == null) {
        return QrScanResult(
          band: band,
          message: '¡Banda encontrada! Bienvenido al perfil de ${band.name}.',
          isOffline: false,
          isSuccess: true,
        );
      }
      await bandsRepo.followBand(band.id, user.id);
      return QrScanResult(
        band: band,
        message: '¡Ahora sigues a ${band.name}! Conexión directa establecida.',
        isOffline: false,
        isSuccess: true,
      );
    } catch (e) {
      // La red falló a mitad del proceso: se encola el id si ya lo tenemos.
      return _queueOffline(band?.id ?? target, band: band);
    }
  }

  /// Un QR trae un id (uuid) o un slug: se consulta por el campo que corresponde.
  Future<Band?> _findBand(String target) =>
      isUuid(target) ? bandsRepo.getBandById(target) : bandsRepo.getBandBySlug(target);

  /// Encola el follow (id o slug; `SessionViewModel.syncPendingFollows` resuelve
  /// el slug al sincronizar) y devuelve el resultado "sin señal".
  Future<QrScanResult> _queueOffline(String target, {Band? band}) async {
    await pendingFollowService.queueFollow(target);
    return QrScanResult(
      band: band,
      message: 'Sin señal en el sótano: quedaste anotado y te sumamos como seguidor apenas recuperes conexión.',
      isOffline: true,
      isSuccess: true,
    );
  }
}
