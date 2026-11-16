// firebase_messaging 17 depreca getToken/onTokenRefresh/deleteToken en favor de
// register()/onRegistered (Firebase Installation ID). Se mantiene a propósito el
// token FCM clásico porque es el destino documentado de `message.token` en la
// API HTTP v1 que usa la Edge Function `send-push`.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/data/services/notifications/background_upload_service.dart';

/// Notificación push ya traducida al dominio de la app.
@immutable
class PushMessage {
  final String? title;
  final String? body;

  /// Banda a abrir al tocar la notificación (`data.band_id` en el payload FCM).
  final String? bandId;

  const PushMessage({this.title, this.body, this.bandId});

  factory PushMessage.fromRemote(RemoteMessage m) => PushMessage(
        title: m.notification?.title,
        body: m.notification?.body,
        bandId: m.data['band_id'] as String?,
      );
}

/// Contrato del servicio de push (permite una versión Fake en tests/offline).
abstract class PushNotificationService {
  /// Inicializa Firebase y pide permiso. Devuelve `false` si push no está disponible.
  Future<bool> initialize();

  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// El usuario tocó una notificación (app en 2.º plano, cerrada o abierta).
  Stream<PushMessage> get openedMessages;

  String get platform;
  Future<void> deleteToken();
  void dispose();
}

/// Handler de mensajes con la app en SEGUNDO PLANO o CERRADA.
///
/// Corre en un isolate aparte creado por el plugin: tiene que ser una función
/// de nivel superior, con `@pragma('vm:entry-point')`, y debe inicializar
/// Firebase por su cuenta (no comparte memoria con la app).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Si el mensaje trae `notification`, Android/iOS ya lo muestran solos.
  debugPrint('[Push] Mensaje en segundo plano: ${message.messageId}');
}

/// Implementación real con Firebase Cloud Messaging (FCM).
///
/// Ciclo completo:
///  1. `initialize()` en `main` (antes de `runApp`): Firebase + permiso + handlers.
///  2. `SessionViewModel` guarda el token en Supabase al iniciar sesión y lo
///     actualiza con `onTokenRefresh`; lo borra al cerrar sesión.
///  3. La Edge Function `send-push` (disparada por un Database Webhook al
///     insertar canciones o donaciones) envía el push con la API HTTP v1 de FCM.
///  4. Al tocar la notificación, [openedMessages] emite y el
///     `NavigationViewModel` abre el perfil de la banda.
class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({required this.localNotifications});

  /// Se usa para MOSTRAR los push que llegan con la app en primer plano
  /// (FCM no los muestra solo en Android) y para capturar sus toques.
  final BackgroundUploadService localNotifications;

  final _openedController = StreamController<PushMessage>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  Completer<bool>? _init;
  bool _available = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  String get platform => kIsWeb ? 'web' : Platform.operatingSystem;

  @override
  Stream<PushMessage> get openedMessages => _openedController.stream;

  @override
  Stream<String> get onTokenRefresh =>
      _available ? _messaging.onTokenRefresh : const Stream<String>.empty();

  @override
  Future<bool> initialize() {
    // Completer: llamadas concurrentes esperan la misma inicialización.
    final existing = _init;
    if (existing != null) return existing.future;
    final completer = _init = Completer<bool>();
    _doInitialize().then(completer.complete, onError: (Object e) {
      debugPrint('[Push] No disponible: $e');
      completer.complete(false);
    });
    return completer.future;
  }

  Future<bool> _doInitialize() async {
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) return false;

    // Requiere google-services.json / GoogleService-Info.plist
    // (los genera `flutterfire configure`). Si faltan, push queda desactivado
    // y la app sigue funcionando normalmente.
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] El usuario rechazó los permisos de notificación.');
      return false;
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await localNotifications.initialize();

    // App ABIERTA: FCM no muestra nada en Android -> notificación local.
    _subs.add(FirebaseMessaging.onMessage.listen((message) {
      final push = PushMessage.fromRemote(message);
      if (push.title == null && push.body == null) return;
      localNotifications.show(
        id: message.hashCode,
        title: push.title ?? 'StreamTunes',
        body: push.body ?? '',
        payload: push.bandId,
      );
    }));

    // Toque sobre la notificación local mostrada en primer plano.
    _subs.add(localNotifications.notificationTaps
        .where((bandId) => bandId != null && bandId.isNotEmpty)
        .listen((bandId) => _openedController.add(PushMessage(bandId: bandId))));

    // App en SEGUNDO PLANO y el usuario toca la notificación.
    _subs.add(FirebaseMessaging.onMessageOpenedApp
        .map(PushMessage.fromRemote)
        .listen(_openedController.add));

    _available = true;

    // App CERRADA y se abrió desde una notificación.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Se emite en el próximo ciclo: así la UI ya está escuchando el stream.
      scheduleMicrotask(() => _openedController.add(PushMessage.fromRemote(initial)));
    }
    return true;
  }

  @override
  Future<String?> getToken() async {
    if (!await initialize()) return null;
    return _messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    if (_available) await _messaging.deleteToken();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _openedController.close();
  }
}

/// Implementación sin push (modo offline, escritorio y tests).
class NoopPushNotificationService implements PushNotificationService {
  @override
  Future<bool> initialize() async => false;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();
  @override
  String get platform => 'none';
  @override
  Future<void> deleteToken() async {}
  @override
  void dispose() {}
}
