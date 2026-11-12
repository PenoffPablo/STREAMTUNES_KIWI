import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/app_config.dart';
import 'package:streamtunes/models/app_user.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/config_repository.dart';

class SessionViewModel extends ChangeNotifier {
  final AuthRepository authRepo;
  final BandsRepository bandsRepo;
  final ConfigRepository configRepo;

  AppUser? _currentUser;
  Band? _activeBand;
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _authSub;

  SessionViewModel({
    required this.authRepo,
    required this.bandsRepo,
    required this.configRepo,
  }) {
    _init();
  }

  AppUser? get currentUser => _currentUser;
  Band? get activeBand => _activeBand;
  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;
  bool get isAnonymous => _currentUser?.isAnonymous ?? true;
  bool get isMusician => _currentUser?.hasAnyBand ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> _init() async {
    _authSub = authRepo.authStateChanges.listen((user) async {
      _currentUser = user;
      if (user != null && user.hasAnyBand) {
        // Cargar primera banda activa
        final firstBandId = user.bandRoles.keys.first;
        _activeBand = await bandsRepo.getBandById(firstBandId);
      } else {
        _activeBand = null;
      }
      notifyListeners();
    });

    await loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      _config = await configRepo.getConfig();
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionViewModel] Error cargando config: $e');
    }
  }

  Future<void> signInAnonymously() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await authRepo.signInAnonymously();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await authRepo.signInWithEmail(email, password);
      if (_currentUser != null && _currentUser!.hasAnyBand) {
        final firstBandId = _currentUser!.bandRoles.keys.first;
        _activeBand = await bandsRepo.getBandById(firstBandId);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await authRepo.signUpWithEmail(email, password, displayName);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
