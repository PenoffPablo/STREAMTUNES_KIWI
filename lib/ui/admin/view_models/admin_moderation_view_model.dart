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
  List<RejectedPayment> _pendingRefunds = [];
  String? _refundingId;
  String? _moneyError;
  StreamSubscription<Donation>? _liveSub;
  AppConfig _config = const AppConfig();
  bool _isLoading = false;
  String? _payingBandId;
  String? _errorMessage;
  String? _payoutError;

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

  /// Por qué falló el último registro de pago (lo muestra la View en un aviso
  /// puntual, separado de los errores generales del panel).
  String? get payoutError => _payoutError;

  /// Estado de cuenta de todas las bandas, mayor saldo a liquidar primero.
  List<BandBalance> get balances => List.unmodifiable(_balances);

  /// Total que KIWI le debe hoy a todas las bandas (ya descontada su comisión).
  double get totalPending => _balances.fold(0, (sum, b) => sum + (b.hasPending ? b.pending : 0));

  bool isPaying(String bandId) => _payingBandId == bandId;

  /// Últimos pagos verificados por Mercado Pago (banda, donante, bruto y neto).
  List<Donation> get recentPayments => List.unmodifiable(_recentPayments);

  /// Error al cargar saldos o pagos. Se muestra en el panel en lugar de una
  /// lista vacía, para no confundir "no hay pagos" con "no se pudo cargar".
  String? get moneyError => _moneyError;

  /// Pagos que KIWI cobró pero no se pudieron registrar como aporte (banda
  /// suspendida, monto mayor al tope...). Hay que devolvérselos al fan.
  List<RejectedPayment> get pendingRefunds => List.unmodifiable(_pendingRefunds);
  double get totalToRefund => _pendingRefunds.fold(0, (sum, r) => sum + r.amount);
  bool isRefunding(String id) => _refundingId == id;

  /// Totales de todas las bandas.
  double get totalCollected => _balances.fold(0, (sum, b) => sum + b.collected);
  double get totalFees => _balances.fold(0, (sum, b) => sum + b.mercadoPagoFees);
  double get totalPaid => _balances.fold(0, (sum, b) => sum + b.paid);
  double get totalNet => _balances.fold(0, (sum, b) => sum + b.netCollected);

  /// Lo que KIWI retuvo para sostener la app (comisión sobre el neto).
  double get totalKiwiFee => _balances.fold(0, (sum, b) => sum + b.kiwiFee);

  /// Lo que les corresponde a las bandas en total (liquidado o no).
  double get totalBandShare => _balances.fold(0, (sum, b) => sum + b.bandShare);

  /// Porcentaje de la comisión de KIWI (para mostrarlo en el panel).
  int get kiwiCommissionPct => _config.kiwiCommissionPct;

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
    await _reloadMoney();
    notifyListeners();
  }

  Future<void> loadModerationData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (bands, reports, config, _) = await (
        moderationRepo.getPendingBands(),
        moderationRepo.getOpenReports(),
        _attempt(configRepo.getConfig, 'la configuración (freno de emergencia y comisión)'),
        _reloadMoney(),
      ).wait;
      _pendingBands = bands;
      _openReports = reports;
      if (config.$1 != null) _config = config.$1!;
      _errorMessage = config.$2;
    } catch (e) {
      _errorMessage = 'No se pudo cargar el panel de moderación. ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Número de la recarga de dinero más reciente ("la última petición gana").
  int _moneyRequestId = 0;

  /// Pide saldos y pagos en paralelo y aplica el resultado SOLO si sigue
  /// siendo la recarga más reciente. Un mismo pago genera varios avisos en
  /// vivo (INSERT y reintentos del webhook): sin esto, una respuesta vieja que
  /// llega última pisaría los números nuevos.
  ///
  /// Cada carga devuelve su propio error (en vez de escribir un campo
  /// compartido), así un error no lo borra otra carga que salió bien. Si una
  /// falla, se conserva lo último cargado y el error queda en [moneyError].
  Future<void> _reloadMoney() async {
    final requestId = ++_moneyRequestId;
    final payouts = payoutsRepo;
    final donations = donationsRepo;
    final (balances, payments, refunds) = await (
      _attempt(payouts?.getAllBalances, 'los saldos de las bandas'),
      _attempt(donations == null ? null : () => donations.getRecentVerified(), 'los últimos pagos'),
      _attempt(payouts?.getPendingRefunds, 'los pagos a devolver'),
    ).wait;
    if (requestId != _moneyRequestId || isDisposed) return; // respuesta vieja

    if (balances.$1 != null) _balances = balances.$1!;
    if (payments.$1 != null) _recentPayments = payments.$1!;
    if (refunds.$1 != null) _pendingRefunds = refunds.$1!;
    _moneyError = balances.$2 ?? payments.$2 ?? refunds.$2;
  }

  /// Ejecuta [load] y devuelve (dato, null) o (null, mensaje de error legible).
  Future<(T?, String?)> _attempt<T>(Future<T> Function()? load, String what) async {
    if (load == null) return (null, null);
    try {
      return (await load(), null);
    } catch (e) {
      return (null, 'No se pudieron cargar $what. ${describeError(e)}');
    }
  }

  /// Registra que KIWI le transfirió [amount] a la banda. La base rechaza
  /// montos mayores al saldo pendiente y avisa a la banda por push.
  Future<bool> registerPayout({required String bandId, required double amount, String? reference, String? note}) async {
    final repo = payoutsRepo;
    if (repo == null || _payingBandId != null) return false;
    _payingBandId = bandId;
    _payoutError = null;
    notifyListeners();
    try {
      await repo.registerPayout(bandId: bandId, amount: amount, reference: reference, note: note);
      await _reloadMoney();
      return true;
    } catch (e) {
      _payoutError = describeError(e);
      return false;
    } finally {
      _payingBandId = null;
      notifyListeners();
    }
  }

  /// El moderador ya le devolvió el pago al fan desde Mercado Pago.
  Future<bool> markRefunded(String rejectedPaymentId) async {
    final repo = payoutsRepo;
    if (repo == null || _refundingId != null) return false;
    _refundingId = rejectedPaymentId;
    _payoutError = null;
    notifyListeners();
    try {
      await repo.markRefunded(rejectedPaymentId);
      _pendingRefunds.removeWhere((r) => r.id == rejectedPaymentId);
      return true;
    } catch (e) {
      _payoutError = describeError(e);
      return false;
    } finally {
      _refundingId = null;
      notifyListeners();
    }
  }

  Future<void> approveBand(String bandId) async {
    try {
      await moderationRepo.reviewBand(bandId, true);
      _pendingBands.removeWhere((b) => b.id == bandId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo aprobar la banda. ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> rejectBand(String bandId) async {
    try {
      await moderationRepo.reviewBand(bandId, false);
      _pendingBands.removeWhere((b) => b.id == bandId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo rechazar la banda. ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> resolveReport(String reportId, {bool hideSong = true}) async {
    try {
      await moderationRepo.resolveReport(reportId, hideSong);
      _openReports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo resolver el reporte. ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> dismissReport(String reportId) async {
    try {
      await moderationRepo.resolveReport(reportId, false);
      _openReports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo desestimar el reporte. ${describeError(e)}';
      notifyListeners();
    }
  }

  bool _isSavingSpendCap = false;

  /// Mientras se guarda el freno, el interruptor queda bloqueado (un doble
  /// toque no manda dos cambios).
  bool get isSavingSpendCap => _isSavingSpendCap;

  Future<void> toggleSpendCap(bool active) async {
    if (_isSavingSpendCap) return;
    _isSavingSpendCap = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await configRepo.updateSpendCap(active);
      _config = _config.copyWith(spendCapActive: active);
    } catch (e) {
      _errorMessage = 'No se pudo cambiar el freno de emergencia. ${describeError(e)}';
    } finally {
      _isSavingSpendCap = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
