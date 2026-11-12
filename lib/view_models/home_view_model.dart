import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/app_user.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/services/pending_follow_service.dart';

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

class HomeViewModel extends ChangeNotifier {
  final SongsRepository songsRepo;
  final BandsRepository bandsRepo;
  final AuthRepository authRepo;
  final PendingFollowService pendingFollowService;

  List<Song> _latestSongs = [];
  List<Band> _approvedBands = [];
  String _selectedGenre = 'Todos';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  HomeViewModel({
    required this.songsRepo,
    required this.bandsRepo,
    required this.authRepo,
    required this.pendingFollowService,
  });

  List<Song> get latestSongs => List.unmodifiable(_latestSongs);
  List<Band> get approvedBands => List.unmodifiable(_approvedBands);
  String get selectedGenre => _selectedGenre;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<void> loadFeed() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final songsFuture = songsRepo.getLatestSongs(
        genre: _selectedGenre == 'Todos' ? null : _selectedGenre,
        query: _searchQuery.isEmpty ? null : _searchQuery,
      );
      final bandsFuture = bandsRepo.getBands(
        status: BandStatus.approved,
        genre: _selectedGenre == 'Todos' ? null : _selectedGenre,
        query: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final results = await Future.wait([songsFuture, bandsFuture]);
      _latestSongs = results[0] as List<Song>;
      _approvedBands = results[1] as List<Band>;
    } catch (e) {
      _errorMessage = 'Error cargando música: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setGenre(String genre) {
    if (_selectedGenre == genre) return;
    _selectedGenre = genre;
    loadFeed();
  }

  void search(String query) {
    _searchQuery = query.trim();
    loadFeed();
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
