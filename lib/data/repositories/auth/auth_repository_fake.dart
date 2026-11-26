import 'dart:async';

import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository.dart';

/// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeAuthRepository implements AuthRepository {
  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();
  final _expiredController = StreamController<void>.broadcast();

  FakeAuthRepository({AppUser? initialUser}) {
    _user = initialUser;
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<void> get sessionExpired => _expiredController.stream;

  @override
  Future<void> reloadProfile() async {
    if (_user != null) _controller.add(_user);
  }

  /// Le da al usuario actual un rol en una banda (simula el trigger
  /// `on_band_created` de la base, para el modo offline y los tests).
  void grantBandRole(String bandId, {String role = 'owner'}) {
    final user = _user;
    if (user == null) return;
    _user = user.copyWith(bandRoles: {...user.bandRoles, bandId: role});
  }

  /// Simula una sesión que venció y no se pudo renovar (para tests).
  void expireSession() {
    _user = null;
    _controller.add(null);
    _expiredController.add(null);
  }

  @override
  Future<AppUser> signInAnonymously() async {
    _user = const AppUser(
      id: 'anon-user-uuid-1234',
      displayName: 'Fan anónimo',
      isAnonymous: true,
      isPublicProfile: false,
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    // Para pruebas directas: email conteniendo 'admin' da rol admin; conteniendo 'artist' da banda
    final isAdmin = email.contains('admin');
    final isArtist = email.contains('artist') || email.contains('fuzz');

    _user = AppUser(
      id: isAdmin
          ? '11111111-1111-1111-1111-111111111111'
          : (isArtist
                ? '22222222-2222-2222-2222-222222222222'
                : '33333333-3333-3333-3333-333333333333'),
      displayName: isAdmin
          ? 'Lucía Colectivo (Admin)'
          : (isArtist ? 'Martín Fuzz' : 'Valeria Indie'),
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      isPublicProfile: true,
      isAnonymous: false,
      isAdmin: isAdmin,
      bandRoles: isArtist
          ? {'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa': 'owner'}
          : {},
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    _user = AppUser(
      id: 'user-new-${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName.isNotEmpty
          ? displayName
          : 'Músico Independiente',
      isPublicProfile: false,
      isAnonymous: false,
      isAdmin: false,
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  }) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
      isPublicProfile: isPublicProfile,
    );
    _controller.add(_user);
  }

  @override
  void dispose() {
    _controller.close();
    _expiredController.close();
  }
}
