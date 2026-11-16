import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _cachedUser;

  SupabaseAuthRepository(this._client) {
    _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        _cachedUser = null;
        _controller.add(null);
      } else {
        await _fetchFullProfile(session.user.id);
      }
    });
  }

  Future<void> _fetchFullProfile(String userId) async {
    try {
      final profileRes =
          await (_client
                  .from('profiles')
                  .select()
                  .eq('id', userId)
                  .maybeSingle())
              .withNetworkTimeout();

      final adminRes =
          await (_client
                  .from('app_admins')
                  .select()
                  .eq('user_id', userId)
                  .maybeSingle())
              .withNetworkTimeout();

      final membersRes =
          await (_client
                  .from('band_members')
                  .select('band_id, role')
                  .eq('user_id', userId))
              .withNetworkTimeout();

      final Map<String, String> bandRoles = {};
      for (final m in membersRes) {
        bandRoles[m['band_id'] as String] = m['role'] as String;
      }

      // Asegurar bandas donde sea el creador directo
      try {
        final ownerBands =
            await (_client.from('bands').select('id').eq('created_by', userId))
                .withNetworkTimeout();
        for (final b in ownerBands) {
          final bId = b['id'] as String?;
          if (bId != null) {
            bandRoles.putIfAbsent(bId, () => 'owner');
          }
        }
      } catch (_) {}

      if (profileRes != null) {
        _cachedUser = AppUser.fromJson(
          profileRes,
          isAdmin: adminRes != null,
          bandRoles: bandRoles,
        );
      } else {
        _cachedUser = AppUser(
          id: userId,
          displayName: 'Fan anónimo',
          isAdmin: adminRes != null,
          bandRoles: bandRoles,
        );
      }
      _controller.add(_cachedUser);
    } catch (e) {
      debugPrint('[SupabaseAuthRepository] Error al obtener perfil: $e');
    }
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Future<AppUser> signInAnonymously() async {
    final res = await (_client.auth.signInAnonymously()).withNetworkTimeout();
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser ??
          AppUser(
            id: res.user!.id,
            displayName: 'Fan anónimo',
            isAnonymous: true,
          );
    }
    throw Exception('Error en autenticación anónima');
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final res = await (_client.auth.signInWithPassword(
      email: email,
      password: password,
    )).withNetworkTimeout();
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser!;
    }
    throw Exception('Credenciales incorrectas');
  }

  @override
  Future<AppUser> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final res = await (_client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    )).withNetworkTimeout();
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser ?? AppUser(id: res.user!.id, displayName: displayName);
    }
    throw Exception('Error al registrar usuario');
  }

  @override
  Future<void> signOut() async {
    await (_client.auth.signOut()).withNetworkTimeout();
    _cachedUser = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  }) async {
    if (_cachedUser == null) return;
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isPublicProfile != null) updates['is_public_profile'] = isPublicProfile;

    await (_client.from('profiles').update(updates).eq('id', _cachedUser!.id))
        .withNetworkTimeout();
    await _fetchFullProfile(_cachedUser!.id);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
