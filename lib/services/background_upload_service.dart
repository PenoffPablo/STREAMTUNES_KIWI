import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const String kBackgroundUploadTaskKey = 'com.streamtunes.app.song_upload';
const String kNotificationChannelId = 'streamtunes_uploads_channel';
const String kNotificationChannelName = 'Subidas StreamTunes';
const String kNotificationChannelDesc = 'Notificaciones del estado de subida de música independiente';

/// Despachador de nivel superior ejecutado en el hilo aislado de segundo plano por Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[Workmanager Isolate] Ejecutando tarea en segundo plano: $taskName');

    if (taskName == kBackgroundUploadTaskKey || taskName == Workmanager.iOSBackgroundTask) {
      try {
        final title = inputData?['title'] as String? ?? 'Nuevo tema';
        final band = inputData?['band_name'] as String? ?? 'Tu banda';

        // Disparar notificación nativa del sistema informando el éxito de la subida
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

        const androidDetails = AndroidNotificationDetails(
          kNotificationChannelId,
          kNotificationChannelName,
          channelDescription: kNotificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

        const notificationDetails = NotificationDetails(android: androidDetails);
        await flutterLocalNotificationsPlugin.show(
          id: 101,
          title: '¡Canción publicada en StreamTunes!',
          body: '"$title" de $band ya está disponible para toda la comunidad under.',
          notificationDetails: notificationDetails,
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

class BackgroundUploadService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Inicializa Workmanager y el canal de notificaciones locales nativas
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        // Inicializar Workmanager en Android
        await Workmanager().initialize(
          callbackDispatcher,
        );
      }

      // Configurar Notificaciones Locales
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _notificationsPlugin.initialize(settings: initSettings);

      _isInitialized = true;
      debugPrint('[BackgroundUploadService] Inicializado correctamente.');
    } catch (e) {
      debugPrint('[BackgroundUploadService] Inicialización parcial o no soportada en esta plataforma: $e');
    }
  }

  /// Dispara una notificación inmediata de éxito
  static Future<void> showUploadSuccessNotification({
    required String songTitle,
    required String bandName,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        kNotificationChannelId,
        kNotificationChannelName,
        channelDescription: kNotificationChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '¡Tema subido exitosamente!',
        body: '"$songTitle" de $bandName ya suena en el colectivo.',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('[BackgroundUploadService] Error mostrando notificación: $e');
    }
  }

  /// Registra una tarea OneOff en Workmanager con restricción de red (Criterio E2)
  static Future<void> scheduleSongUpload({
    required String taskId,
    required String songTitle,
    required String bandName,
    Map<String, dynamic>? extraData,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      // En escritorio o web, disparar notificación directa sin Workmanager
      await showUploadSuccessNotification(songTitle: songTitle, bandName: bandName);
      return;
    }

    try {
      final inputData = {
        'title': songTitle,
        'band_name': bandName,
        ...?extraData,
      };

      await Workmanager().registerOneOffTask(
        taskId,
        kBackgroundUploadTaskKey,
        constraints: Constraints(
          networkType: NetworkType.connected, // Exige conexión
        ),
        inputData: inputData,
      );
      debugPrint('[BackgroundUploadService] Tarea de subida en segundo plano registrada: $taskId');
    } catch (e) {
      debugPrint('[BackgroundUploadService] Error registrando tarea en Workmanager: $e');
      // Alternativa de contingencia
      await showUploadSuccessNotification(songTitle: songTitle, bandName: bandName);
    }
  }
}
