import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Guarda los tokens en la tabla `device_tokens` (ver supabase/migrations).
/// RLS: cada usuario solo puede ver y modificar sus propios tokens.
class SupabaseDeviceTokensRepository implements DeviceTokensRepository {
  SupabaseDeviceTokensRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> saveToken({required String userId, required String token, required String platform}) {
    // upsert por token: si el mismo dispositivo cambia de usuario, se reasigna.
    return _client.from('device_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token').withNetworkTimeout();
  }

  @override
  Future<void> deleteToken(String token) {
    return _client.from('device_tokens').delete().eq('token', token).withNetworkTimeout();
  }
}
