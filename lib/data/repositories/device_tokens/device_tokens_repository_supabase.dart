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
    // RPC: asigna el token al usuario de la SESIÓN (no al userId que manda la
    // app) y lo reasigna si el teléfono tenía otra cuenta. Un upsert directo
    // fallaba por RLS cuando la cuenta anterior no había borrado su token.
    return _client.rpc('register_device_token', params: {'p_token': token, 'p_platform': platform}).withNetworkTimeout();
  }

  @override
  Future<void> deleteToken(String token) {
    return _client.from('device_tokens').delete().eq('token', token).withNetworkTimeout();
  }
}
