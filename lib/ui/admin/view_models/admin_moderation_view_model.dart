import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/report.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class AdminModerationViewModel extends ViewModel {
  final ModerationRepository moderationRepo;
  final ConfigRepository configRepo;

  List<Band> _pendingBands = [];
  List<SongReport> _openReports = [];
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _errorMessage;

  AdminModerationViewModel({
    required this.moderationRepo,
    required this.configRepo,
  });

  List<Band> get pendingBands => List.unmodifiable(_pendingBands);
  List<SongReport> get openReports => List.unmodifiable(_openReports);
  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadModerationData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (bands, reports, config) = await (
        moderationRepo.getPendingBands(),
        moderationRepo.getOpenReports(),
        configRepo.getConfig(),
      ).wait;
      _pendingBands = bands;
      _openReports = reports;
      _config = config;
    } catch (e) {
      _errorMessage = 'Error cargando datos de moderación: ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveBand(String bandId) async {
    try {
      await moderationRepo.reviewBand(bandId, true);
      _pendingBands.removeWhere((b) => b.id == bandId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error aprobando banda: $e';
      notifyListeners();
    }
  }

  Future<void> rejectBand(String bandId) async {
    try {
      await moderationRepo.reviewBand(bandId, false);
      _pendingBands.removeWhere((b) => b.id == bandId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error rechazando banda: $e';
      notifyListeners();
    }
  }

  Future<void> resolveReport(String reportId, {bool hideSong = true}) async {
    try {
      await moderationRepo.resolveReport(reportId, hideSong);
      _openReports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error resolviendo reporte: $e';
      notifyListeners();
    }
  }

  Future<void> dismissReport(String reportId) async {
    try {
      await moderationRepo.resolveReport(reportId, false);
      _openReports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error desestimando reporte: $e';
      notifyListeners();
    }
  }

  Future<void> toggleSpendCap(bool active) async {
    try {
      await configRepo.updateSpendCap(active);
      _config = _config.copyWith(spendCapActive: active);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error actualizando tope de gastos: $e';
      notifyListeners();
    }
  }
}
