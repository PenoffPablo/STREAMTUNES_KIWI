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
import 'package:streamtunes/utils/stream_transformers.dart';

class QrScanResult {
  final Band? band;
  final String message;
  final bool isOffline;
  final bool isSuccess;

  const QrScanResult({
    this.band,
    required this.message,
    required this.isOffline,
    required this.isSuccess,
  });
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
    _querySub ??= _queryController.stream
        .map((q) => q.trim())
        .distinct()
        .transform(debounce(searchDebounce))
        .listen((query) {
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
      _errorMessage = 'Error cargando música: ${describeError(e)}';
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
      return const QrScanResult(
        message: 'Código QR inválido o vacío.',
        isOffline: false,
        isSuccess: false,
      );
    }

    // Extraer slug o ID de la banda (admite streamtunes://band/slug o https://... o ID plano)
    String target = cleaned;
    if (cleaned.contains('/band/')) {
      target = cleaned.split('/band/').last.split('?').first;
    }
    target = target.replaceAll(RegExp(r'/+$'), '').trim();

    // Caso SÓTANO UNDERGROUND (Sin conexión a internet)
    if (simulateOffline) {
      await pendingFollowService.queueFollow(target);
      Band? cachedBand = await bandsRepo.getBandById(target);
      cachedBand ??= await bandsRepo.getBandBySlug(target);

      return QrScanResult(
        band: cachedBand,
        message: 'Sin señal en el sótano: quedaste anotado y te sumamos como seguidor apenas recuperes conexión.',
        isOffline: true,
        isSuccess: true,
      );
    }

    try {
      // 1. Obtener banda por ID o slug
      Band? band = await bandsRepo.getBandById(target);
      band ??= await bandsRepo.getBandBySlug(target);

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

      // 3. Registrar el seguimiento si tenemos ID de usuario
      bool followed = false;
      if (user != null) {
        try {
          await bandsRepo.followBand(band.id, user.id);
          followed = true;
        } catch (_) {}
      }

      return QrScanResult(
        band: band,
        message: followed || user != null
            ? '¡Ahora sigues a ${band.name}! Conexión directa establecida.'
            : '¡Banda encontrada! Bienvenido al perfil de ${band.name}.',
        isOffline: false,
        isSuccess: true,
      );
    } catch (e) {
      // Alternativa de contingencia a sótano si la red falló durante el proceso
      await pendingFollowService.queueFollow(target);
      return const QrScanResult(
        message: 'Sin señal en el sótano: quedaste anotado y te sumamos como seguidor apenas recuperes conexión.',
        isOffline: true,
        isSuccess: true,
      );
    }
  }
}
