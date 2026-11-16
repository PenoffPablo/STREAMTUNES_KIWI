import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const String kBackgroundUploadTaskKey = 'com.streamtunes.app.song_upload';
const String kNotificationChannelId = 'streamtunes_uploads_channel';
const String kNotificationChannelName = 'Subidas StreamTunes';
const String kNotificationChannelDesc = 'Notificaciones del estado de subida de música independiente';

const AndroidNotificationDetails _uploadChannel = AndroidNotificationDetails(
  kNotificationChannelId,
  kNotificationChannelName,
  channelDescription: kNotificationChannelDesc,
  importance: Importance.high,
  priority: Priority.high,
  showWhen: true,
);

/// Despachador de nivel superior ejecutado por Workmanager en un isolate de
/// segundo plano propio (sin acceso a la memoria de la app principal).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[Workmanager Isolate] Ejecutando tarea en segundo plano: $taskName');

    if (taskName == kBackgroundUploadTaskKey || taskName == Workmanager.iOSBackgroundTask) {
      try {
        final title = inputData?['title'] as String? ?? 'Nuevo tema';
        final band = inputData?['band_name'] as String? ?? 'Tu banda';

        final plugin = FlutterLocalNotificationsPlugin();
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );
        await plugin.initialize(settings: initSettings);
        await plugin.show(
          id: 101,
          title: '¡Canción publicada en StreamTunes!',
          body: '"$title" de $band ya está disponible para toda la comunidad under.',
          notificationDetails: const NotificationDetails(android: _uploadChannel),
        );
        return true;
      } catch (e) {
        debugPrint('[Workmanager Isolate] Error en tarea de subida: $e');
        return false;
      }
    }
    return true;
  });
}

/// Notificaciones locales + tareas en segundo plano (Workmanager).
///
/// Es una instancia inyectable (antes era una clase con métodos `static`), así
/// los ViewModels no dependen de una implementación concreta y se puede
/// reemplazar en tests.
class BackgroundUploadService {
  BackgroundUploadService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Completer de inicialización: si `initialize()` se llama varias veces a la
  /// vez (main + servicio de push), todas esperan el MISMO trabajo en curso.
  Completer<void>? _initCompleter;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Payloads de las notificaciones locales que el usuario tocó (por ejemplo,
  /// un push recibido con la app abierta y mostrado como notificación local).
  final _tapController = StreamController<String?>.broadcast();
  Stream<String?> get notificationTaps => _tapController.stream;

  /// Inicializa Workmanager y el canal de notificaciones locales nativas.
  Future<void> initialize() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;
    final completer = _initCompleter = Completer<void>();
    _doInitialize().then(completer.complete, onError: completer.completeError);
    return completer.future;
  }

  Future<void> _doInitialize() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await Workmanager().initialize(callbackDispatcher);
      }
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (!_tapController.isClosed) _tapController.add(response.payload);
        },
      );
      debugPrint('[BackgroundUploadService] Inicializado correctamente.');
    } catch (e) {
      // No es fatal: en escritorio/tests no hay plugin nativo.
      debugPrint('[BackgroundUploadService] Inicialización parcial o no soportada: $e');
    }
  }

  /// Muestra una notificación local genérica (la usa también el servicio de push
  /// para mostrar mensajes recibidos con la app en primer plano).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(android: _uploadChannel),
      );
    } catch (e) {
      debugPrint('[BackgroundUploadService] Error mostrando notificación: $e');
    }
  }

  void dispose() => _tapController.close();

  /// Dispara una notificación inmediata de éxito.
  Future<void> showUploadSuccessNotification({
    required String songTitle,
    required String bandName,
  }) {
    return show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '¡Tema subido exitosamente!',
      body: '"$songTitle" de $bandName ya suena en el colectivo.',
    );
  }

  /// Registra una tarea OneOff en Workmanager con restricción de red.
  Future<void> scheduleSongUpload({
    required String taskId,
    required String songTitle,
    required String bandName,
    Map<String, dynamic>? extraData,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      await showUploadSuccessNotification(songTitle: songTitle, bandName: bandName);
      return;
    }
    try {
      await Workmanager().registerOneOffTask(
        taskId,
        kBackgroundUploadTaskKey,
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: {'title': songTitle, 'band_name': bandName, ...?extraData},
      );
      debugPrint('[BackgroundUploadService] Tarea en segundo plano registrada: $taskId');
    } catch (e) {
      debugPrint('[BackgroundUploadService] Error registrando tarea en Workmanager: $e');
      await showUploadSuccessNotification(songTitle: songTitle, bandName: bandName);
    }
  }
}
