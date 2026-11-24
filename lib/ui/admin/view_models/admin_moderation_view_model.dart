import 'dart:async';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
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
  final DonationsRepository? donationsRepo;

  List<Band> _pendingBands = [];
  List<SongReport> _openReports = [];
  List<BandBalance> _balances = [];
  List<Donation> _recentPayments = [];
  String? _moneyError;
  StreamSubscription<Donation>? _liveSub;
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _payingBandId;
  String? _errorMessage;

  AdminModerationViewModel({
    required this.moderationRepo,
    required this.configRepo,
    this.payoutsRepo,
    this.donationsRepo,
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

  /// Últimos pagos verificados por Mercado Pago (banda, donante, bruto y neto).
  List<Donation> get recentPayments => List.unmodifiable(_recentPayments);

  /// Error al cargar saldos o pagos. Se muestra en el panel en lugar de una
  /// lista vacía, para no confundir "no hay pagos" con "no se pudo cargar".
  String? get moneyError => _moneyError;

  /// Totales de todas las bandas.
  double get totalCollected => _balances.fold(0, (sum, b) => sum + b.collected);
  double get totalFees => _balances.fold(0, (sum, b) => sum + b.mercadoPagoFees);
  double get totalPaid => _balances.fold(0, (sum, b) => sum + b.paid);

  /// Carga el panel y se suscribe a los pagos en vivo: cada vez que el webhook
  /// aprueba un aporte, se recalculan los saldos y la lista de pagos sin que el
  /// moderador tenga que recargar. Lo llama la View en `initState`.
  Future<void> init() {
    _liveSub ??= donationsRepo?.donationCreatedStream
        .where((d) => d.isApproved)
        .listen((_) => unawaited(refreshMoney()));
    return loadModerationData();
  }

  /// Recarga solo saldos y pagos (lo dispara un pago nuevo o una liquidación).
  Future<void> refreshMoney() async {
    final (balances, payments) = await (_loadBalancesSafely(), _loadPaymentsSafely()).wait;
    _balances = balances;
    _recentPayments = payments;
    notifyListeners();
  }

  Future<void> loadModerationData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _moneyError = null;
      final (bands, reports, config, balances, payments) = await (
        moderationRepo.getPendingBands(),
        moderationRepo.getOpenReports(),
        configRepo.getConfig(),
        _loadBalancesSafely(),
        _loadPaymentsSafely(),
      ).wait;
      _pendingBands = bands;
      _openReports = reports;
      _config = config;
      _balances = balances;
      _recentPayments = payments;
    } catch (e) {
      _errorMessage = 'Error cargando datos de moderación: ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Los saldos son una sección más: si fallan, el resto del panel carga
  /// igual, pero el error queda visible en [moneyError].
  Future<List<BandBalance>> _loadBalancesSafely() async {
    final repo = payoutsRepo;
    if (repo == null) return const [];
    try {
      final balances = await repo.getAllBalances();
      _moneyError = null;
      return balances;
    } catch (e) {
      _moneyError = 'No se pudieron cargar los saldos: ${describeError(e)}';
      return _balances; // se conserva lo último cargado
    }
  }

  Future<List<Donation>> _loadPaymentsSafely() async {
    final repo = donationsRepo;
    if (repo == null) return const [];
    try {
      return await repo.getRecentVerified();
    } catch (e) {
      _moneyError = 'No se pudieron cargar los pagos: ${describeError(e)}';
      return _recentPayments;
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
      _balances = await _loadBalancesSafely();
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

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
