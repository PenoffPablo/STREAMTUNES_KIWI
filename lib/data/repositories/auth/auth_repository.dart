import 'dart:async';

import 'package:streamtunes/domain/models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  /// Avisa cuando la sesión venció y no se pudo renovar (por ejemplo, un
  /// refresh token que el servidor ya no reconoce). En ese momento
  /// [authStateChanges] ya emitió `null`: hay que volver a iniciar sesión.
  Stream<void> get sessionExpired;
  AppUser? get currentUser;
  Future<AppUser> signInAnonymously();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(
    String email,
    String password,
    String displayName,
  );
  Future<void> signOut();

  /// Vuelve a leer el perfil y los roles de banda del usuario actual (por
  /// ejemplo, después de registrar una banda) y lo emite en [authStateChanges].
  Future<void> reloadProfile();
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  });
  void dispose();
}
