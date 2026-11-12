import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ConfigRepository {
  Future<AppConfig> getConfig();
  Future<void> updateSpendCap(bool active);
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeConfigRepository implements ConfigRepository {
  AppConfig _config = const AppConfig();

  FakeConfigRepository({AppConfig? initialConfig}) {
    if (initialConfig != null) {
      _config = initialConfig;
    }
  }

  @override
  Future<AppConfig> getConfig() async => _config;

  @override
  Future<void> updateSpendCap(bool active) async {
    _config = _config.copyWith(spendCapActive: active);
  }
}

//// Implementación real conectada a Supabase
class SupabaseConfigRepository implements ConfigRepository {
  final SupabaseClient _client;

  SupabaseConfigRepository(this._client);

  @override
  Future<AppConfig> getConfig() async {
    try {
      final res = await _client.from('app_config').select('key, value');
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
    await _client
        .from('app_config')
        .update({'value': active ? '1' : '0'})
        .eq('key', 'spend_cap_active');
  }
}

