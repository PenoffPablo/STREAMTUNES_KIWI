import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<AppUser> signInAnonymously();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(String email, String password, String displayName);
  Future<void> signOut();
  Future<void> updateProfile({String? displayName, String? avatarUrl, bool? isPublicProfile});
  void dispose();
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeAuthRepository implements AuthRepository {
  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  FakeAuthRepository({AppUser? initialUser}) {
    _user = initialUser;
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

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
          : (isArtist ? '22222222-2222-2222-2222-222222222222' : '33333333-3333-3333-3333-333333333333'),
      displayName: isAdmin
          ? 'Lucía Colectivo (Admin)'
          : (isArtist ? 'Martín Fuzz' : 'Valeria Indie'),
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      isPublicProfile: true,
      isAnonymous: false,
      isAdmin: isAdmin,
      bandRoles: isArtist ? {'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa': 'owner'} : {},
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password, String displayName) async {
    _user = AppUser(
      id: 'user-new-${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName.isNotEmpty ? displayName : 'Músico Independiente',
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
  Future<void> updateProfile({String? displayName, String? avatarUrl, bool? isPublicProfile}) async {
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
  }
}

//// Implementación real conectada a Supabase
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
      final profileRes = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final adminRes = await _client
          .from('app_admins')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final membersRes = await _client
          .from('band_members')
          .select('band_id, role')
          .eq('user_id', userId);

      final Map<String, String> bandRoles = {};
      for (final m in membersRes) {
        bandRoles[m['band_id'] as String] = m['role'] as String;
      }

      // Asegurar bandas donde sea el creador directo
      try {
        final ownerBands = await _client
            .from('bands')
            .select('id')
            .eq('created_by', userId);
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
    final res = await _client.auth.signInAnonymously();
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser ?? AppUser(id: res.user!.id, displayName: 'Fan anónimo', isAnonymous: true);
    }
    throw Exception('Error en autenticación anónima');
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser!;
    }
    throw Exception('Credenciales incorrectas');
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password, String displayName) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    if (res.user != null) {
      await _fetchFullProfile(res.user!.id);
      return _cachedUser ?? AppUser(id: res.user!.id, displayName: displayName);
    }
    throw Exception('Error al registrar usuario');
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _cachedUser = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile({String? displayName, String? avatarUrl, bool? isPublicProfile}) async {
    if (_cachedUser == null) return;
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isPublicProfile != null) updates['is_public_profile'] = isPublicProfile;

    await _client.from('profiles').update(updates).eq('id', _cachedUser!.id);
    await _fetchFullProfile(_cachedUser!.id);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

