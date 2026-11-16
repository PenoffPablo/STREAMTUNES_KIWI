import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository.dart';

/// Implementación en memoria (modo offline / tests).
class FakeDeviceTokensRepository implements DeviceTokensRepository {
  final Map<String, String> tokensByValue = {}; // token -> userId

  @override
  Future<void> saveToken({required String userId, required String token, required String platform}) async {
    tokensByValue[token] = userId;
  }

  @override
  Future<void> deleteToken(String token) async {
    tokensByValue.remove(token);
  }
}
