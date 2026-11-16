import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabaseConfigRepository implements ConfigRepository {
  final SupabaseClient _client;

  SupabaseConfigRepository(this._client);

  @override
  Future<AppConfig> getConfig() async {
    try {
      final res = await (_client.from('app_config').select('key, value'))
          .withNetworkTimeout();
      final Map<String, String> map = {};
      for (final row in res as List) {
        map[row['key'] as String] = row['value'] as String;
      }
      return AppConfig.fromMap(map);
    } catch (e) {
      debugPrint('[SupabaseConfigRepository] Error al obtener config: $e');
      return const AppConfig();
    }
  }

  @override
  Future<void> updateSpendCap(bool active) async {
    await (_client
            .from('app_config')
            .update({'value': active ? '1' : '0'})
            .eq('key', 'spend_cap_active'))
        .withNetworkTimeout();
  }
}
