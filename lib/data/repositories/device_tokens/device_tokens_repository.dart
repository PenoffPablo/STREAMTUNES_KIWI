/// Registro de los tokens FCM de cada dispositivo del usuario.
///
/// La Edge Function `send-push` lee esta tabla para saber a qué dispositivos
/// mandar cada notificación (por ejemplo, a todos los seguidores de una banda).
abstract class DeviceTokensRepository {
  Future<void> saveToken({required String userId, required String token, required String platform});
  Future<void> deleteToken(String token);
}
