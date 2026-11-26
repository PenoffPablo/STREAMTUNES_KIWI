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
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/utils/ids.dart';

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
  StreamSubscription<void>? _expiredSub;
  final _sessionExpiredController = StreamController<void>.broadcast();
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

  /// Mensaje que ve el usuario cuando su sesión venció.
  static const sessionExpiredMessage = 'Tu sesión venció. Volvé a iniciar sesión para seguir.';

  /// Evento puntual: la sesión venció. La navegación cierra las pantallas
  /// abiertas y lleva a "Cuenta" para iniciar sesión de nuevo.
  Stream<void> get sessionExpired => _sessionExpiredController.stream;
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
            _errorMessage = 'Hubo un problema con tu sesión. ${describeError(e)}';
            notifyListeners();
          },
        );
    _expiredSub = authRepo.sessionExpired.listen((_) {
      _currentUser = null;
      _activeBand = null;
      _pushRegisteredFor = null;
      _errorMessage = sessionExpiredMessage;
      notifyListeners();
      if (!_sessionExpiredController.isClosed) _sessionExpiredController.add(null);
    });
    // Si el token FCM rota, se vuelve a registrar para el usuario actual.
    _tokenRefreshSub = push?.onTokenRefresh.listen((token) async {
      try {
        await _saveToken(token);
      } catch (e) {
        // Sin red: se vuelve a registrar en el próximo inicio de sesión.
        _pushRegisteredFor = null;
        debugPrint('[SessionViewModel] No se pudo guardar el token renovado: $e');
      }
    });
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
      // "Invalid login credentials" -> "Email o contraseña incorrectos.", etc.
      _errorMessage = describeError(e);
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
      _errorMessage = 'No se pudo cambiar la privacidad de tu perfil. ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> switchActiveBand(String bandId) async {
    try {
      final band = await bandsRepo.getBandById(bandId);
      if (band != null) {
        _activeBand = band;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'No se pudo cambiar de banda. ${describeError(e)}';
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
        .sync((target) => _followQueued(target, user.id))
        .whenComplete(() => _syncInFlight = null);
  }

  /// La cola guarda un id o, si se escaneó sin señal, el slug del QR.
  /// `band_follows.band_id` es uuid: el slug se resuelve primero. Un error de
  /// red se propaga (queda en la cola); si la banda ya no existe, devuelve
  /// `true` para sacarla de la cola en vez de reintentar para siempre.
  Future<bool> _followQueued(String target, String userId) async {
    final bandId = isUuid(target) ? target : (await bandsRepo.getBandBySlug(target))?.id;
    if (bandId == null) return true;
    return bandsRepo.followBand(bandId, userId);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tokenRefreshSub?.cancel();
    _expiredSub?.cancel();
    _sessionExpiredController.close();
    super.dispose();
  }
}
