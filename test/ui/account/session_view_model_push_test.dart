import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository_fake.dart';
import 'package:streamtunes/data/services/device/deep_link_service.dart';
import 'package:streamtunes/data/services/notifications/push_notification_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/navigation/view_models/navigation_view_model.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';

/// Servicio de push simulado: permite emitir "toques" y rotar el token.
class _FakePush implements PushNotificationService {
  String token = 'token-1';
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> initialize() async => true;
  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get openedMessages => opened.stream;
  @override
  String get platform => 'android';
  @override
  Future<void> deleteToken() async {}
  @override
  void dispose() {
    refresh.close();
    opened.close();
  }
}

class _NoLinks extends DeepLinkService {
  @override
  Stream<String> get bandLinks => const Stream.empty();
}

void main() {
  late FakeAuthRepository auth;
  late FakeBandsRepository bands;
  late FakeDeviceTokensRepository tokens;
  late _FakePush push;
  late SessionViewModel session;

  setUp(() async {
    auth = FakeAuthRepository();
    bands = FakeBandsRepository();
    tokens = FakeDeviceTokensRepository();
    push = _FakePush();
    session = SessionViewModel(
      authRepo: auth,
      bandsRepo: bands,
      configRepo: FakeConfigRepository(),
      push: push,
      deviceTokens: tokens,
    );
    await session.init();
  });

  tearDown(() {
    session.dispose();
    push.dispose();
    auth.dispose();
  });

  test('al iniciar sesión se registra el token FCM del dispositivo para el usuario', () async {
    await session.signInWithEmail('fan@correo.com', 'pass123');
    await pumpEventQueue();
    expect(tokens.tokensByValue['token-1'], session.currentUser!.id);
  });

  test('si FCM rota el token (onTokenRefresh) se vuelve a guardar', () async {
    await session.signInWithEmail('fan@correo.com', 'pass123');
    push.refresh.add('token-2');
    await pumpEventQueue();
    expect(tokens.tokensByValue['token-2'], session.currentUser!.id);
  });

  test('al cerrar sesión se borra el token: el dispositivo deja de recibir push', () async {
    await session.signInWithEmail('fan@correo.com', 'pass123');
    await pumpEventQueue();
    await session.signOut();
    expect(tokens.tokensByValue, isEmpty);
  });

  test('tocar una notificación abre la banda (sin seguirla)', () async {
    final nav = NavigationViewModel(bandsRepo: bands, deepLinks: _NoLinks(), session: session, push: push)..init();
    addTearDown(nav.dispose);
    await session.signInWithEmail('fan@correo.com', 'pass123');
    const bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    final wasFollowing = await bands.isFollowing(bandId, session.currentUser!.id);

    final opened = nav.openBandRequests.first;
    push.opened.add(const PushMessage(title: 'Nuevo tema', bandId: bandId));
    final Band band = await opened;

    expect(band.id, bandId);
    expect(await bands.isFollowing(bandId, session.currentUser!.id), wasFollowing);
  });
}
