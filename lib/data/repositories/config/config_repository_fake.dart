import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';

/// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
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
