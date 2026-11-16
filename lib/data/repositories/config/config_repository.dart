import 'package:streamtunes/domain/models/app_config.dart';

abstract class ConfigRepository {
  Future<AppConfig> getConfig();
  Future<void> updateSpendCap(bool active);
}
