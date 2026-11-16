import 'dart:async';

import 'package:streamtunes/domain/models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<AppUser> signInAnonymously();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(
    String email,
    String password,
    String displayName,
  );
  Future<void> signOut();
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  });
  void dispose();
}
