import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository.dart';
import 'package:streamtunes/domain/models/report.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class AdminModerationViewModel extends ViewModel {
  final ModerationRepository moderationRepo;
  final ConfigRepository configRepo;
  final PayoutsRepository? payoutsRepo;

  List<Band> _pendingBands = [];
  List<SongReport> _openReports = [];
  List<BandBalance> _balances = [];
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _payingBandId;
  String? _errorMessage;

  AdminModerationViewModel({
    required this.moderationRepo,
    required this.configRepo,
    this.payoutsRepo,
  });

  List<Band> get pendingBands => List.unmodifiable(_pendingBands);
  List<SongReport> get openReports => List.unmodifiable(_openReports);
  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Estado de cuenta de todas las bandas, mayor saldo a liquidar primero.
  List<BandBalance> get balances => List.unmodifiable(_balances);

  /// Total que KIWI le debe hoy a todas las bandas.
  double get totalPending => _balances.fold(0, (sum, b) => sum + (b.hasPending ? b.pending : 0));

  bool isPaying(String bandId) => _payingBandId == bandId;

  Future<void> loadModerationData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (bands, reports, config, balances) = await (
        moderationRepo.getPendingBands(),
        moderationRepo.getOpenReports(),
        configRepo.getConfig(),
        _loadBalancesSafely(),
      ).wait;
      _pendingBands = bands;
      _openReports = reports;
      _config = config;
      _balances = balances;
    } catch (e) {
      _errorMessage = 'Error cargando datos de moderación: ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Los saldos son una sección más: si fallan, el resto del panel carga igual.
  Future<List<BandBalance>> _loadBalancesSafely() async {
    final repo = payoutsRepo;
    if (repo == null) return const [];
    try {
      return await repo.getAllBalances();
    } catch (_) {
      return const [];
    }
  }

  /// Registra que KIWI le transfirió [amount] a la banda. La base rechaza
  /// montos mayores al saldo pendiente y avisa a la banda por push.
  Future<bool> registerPayout({
    required String bandId,
    required double amount,
    String? reference,
    String? note,
  }) async {
    final repo = payoutsRepo;
    if (repo == null || _payingBandId != null) return false;
    _payingBandId = bandId;
    _errorMessage = null;
    notifyListeners();
    try {
      await repo.registerPayout(bandId: bandId, amount: amount, reference: reference, note: note);
      _balances = await repo.getAllBalances();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo registrar el pago: ${describeError(e)}';
      return false;
    } finally {
      _payingBandId = null;
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
