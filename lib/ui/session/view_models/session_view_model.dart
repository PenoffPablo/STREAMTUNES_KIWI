import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository.dart';
import 'package:streamtunes/data/services/notifications/push_notification_service.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/view_model.dart';

class SessionViewModel extends ViewModel {
  final AuthRepository authRepo;
  final BandsRepository bandsRepo;
  final ConfigRepository configRepo;
  final PendingFollowService? pendingFollowService;
  final PushNotificationService? push;
  final DeviceTokensRepository? deviceTokens;

  AppUser? _currentUser;
  Band? _activeBand;
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<(AppUser?, Band?)>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _pushRegisteredFor;
  Future<void>? _initFuture;
  Future<int>? _syncInFlight;

  SessionViewModel({
    required this.authRepo,
    required this.bandsRepo,
    required this.configRepo,
    this.pendingFollowService,
    this.push,
    this.deviceTokens,
  });

  AppUser? get currentUser => _currentUser;
  Band? get activeBand => _activeBand;
  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;
  bool get isAnonymous => _currentUser?.isAnonymous ?? true;
  bool get isMusician => _currentUser?.hasAnyBand ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Inicialización explícita (no en el constructor): la llama el dueño del
  /// ViewModel en `initState`. Es idempotente y devuelve un Future esperable.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _currentUser = authRepo.currentUser;
    // asyncMap procesa los eventos de auth EN ORDEN: si llegan dos cambios
    // seguidos, el segundo espera a que termine la carga de banda del primero.
    _authSub = authRepo.authStateChanges
        .asyncMap((user) async => (user, await _loadFirstBand(user)))
        .listen(
      (event) {
        final (user, band) = event;
        _currentUser = user;
        _activeBand = band;
        notifyListeners();
        unawaited(_syncPushRegistration());
      },
      onError: (Object e) {
        _errorMessage = 'Error de sesión: $e';
        notifyListeners();
      },
    );
    // Si el token FCM rota, se vuelve a registrar para el usuario actual.
    _tokenRefreshSub = push?.onTokenRefresh.listen((token) => _saveToken(token));
    await loadConfig();
    unawaited(_syncPushRegistration());
  }

  /// Registra el token del dispositivo para el usuario logueado (una vez por usuario).
  Future<void> _syncPushRegistration() async {
    final user = _currentUser;
    if (push == null || deviceTokens == null || user == null || user.isAnonymous) return;
    if (_pushRegisteredFor == user.id) return;
    _pushRegisteredFor = user.id;
    try {
      final token = await push!.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      _pushRegisteredFor = null; // reintentar en el próximo cambio de sesión
      debugPrint('[SessionViewModel] No se pudo registrar el token push: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _currentUser;
    if (user == null || user.isAnonymous || deviceTokens == null) return;
    await deviceTokens!.saveToken(userId: user.id, token: token, platform: push!.platform);
  }

  Future<Band?> _loadFirstBand(AppUser? user) async {
    if (user == null || !user.hasAnyBand) return null;
    try {
      return await bandsRepo.getBandById(user.bandRoles.keys.first);
    } catch (e) {
      debugPrint('[SessionViewModel] No se pudo cargar la banda activa: $e');
      return null;
    }
  }

  Future<void> loadConfig() async {
    try {
      _config = await configRepo.getConfig();
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionViewModel] Error cargando config: $e');
    }
  }

  /// Ejecuta una acción de autenticación manejando loading/error de forma uniforme.
  Future<void> _runAuth(Future<AppUser?> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await action();
      _currentUser = user;
      _activeBand = await _loadFirstBand(user);
      unawaited(_syncPushRegistration());
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() => _runAuth(authRepo.signInAnonymously);

  Future<void> signInWithEmail(String email, String password) =>
      _runAuth(() => authRepo.signInWithEmail(email, password));

  Future<void> signUpWithEmail(String email, String password, String displayName) =>
      _runAuth(() => authRepo.signUpWithEmail(email, password, displayName));

  Future<void> signOut() async {
    // El dispositivo deja de recibir push de esta cuenta.
    try {
      final token = await push?.getToken();
      if (token != null) await deviceTokens?.deleteToken(token);
    } catch (e) {
      debugPrint('[SessionViewModel] No se pudo borrar el token push: $e');
    }
    _pushRegisteredFor = null;
    await authRepo.signOut();
    _currentUser = null;
    _activeBand = null;
    notifyListeners();
  }

  Future<void> togglePrivacyOptIn(bool value) async {
    if (_currentUser == null) return;
    try {
      await authRepo.updateProfile(isPublicProfile: value);
      _currentUser = _currentUser!.copyWith(isPublicProfile: value);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error actualizando privacidad: $e';
      notifyListeners();
    }
  }

  Future<void> switchActiveBand(String bandId) async {
    final band = await bandsRepo.getBandById(bandId);
    if (band != null) {
      _activeBand = band;
      notifyListeners();
    }
  }

  void setActiveBand(Band band) {
    _activeBand = band;
    notifyListeners();
  }

  /// Sincroniza los follows hechos sin conexión (QR en el sótano).
  /// Lo llama la raíz de la app cuando vuelve a primer plano (AppLifecycleState.resumed).
  /// Si ya hay una sincronización en curso, devuelve la misma (no se duplican requests).
  Future<int> syncPendingFollows() {
    final service = pendingFollowService;
    final user = _currentUser;
    if (service == null || user == null) return Future.value(0);
    return _syncInFlight ??= service
        .sync((bandId) => bandsRepo.followBand(bandId, user.id))
        .whenComplete(() => _syncInFlight = null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }
}
