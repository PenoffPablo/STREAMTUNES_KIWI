import 'package:streamtunes/data/repositories/payouts/payouts_repository.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación en memoria (modo offline / tests). Se inicializa con el neto
/// cobrado por banda; los pagos se descuentan igual que en la base.
class FakePayoutsRepository implements PayoutsRepository {
  FakePayoutsRepository({Map<String, ({String name, double gross, double net})>? collected})
      : _collected = collected ??
            {
              'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa': (name: 'Los Fuzzers', gross: 3500, net: 3290),
            };

  final Map<String, ({String name, double gross, double net})> _collected;
  final List<BandPayout> _payouts = [];
  final List<RejectedPayment> _rejected = [];

  /// Simula un pago que el webhook no pudo registrar (para tests).
  void addRejected(RejectedPayment payment) => _rejected.add(payment);

  @override
  Future<List<RejectedPayment>> getPendingRefunds() async => List.of(_rejected);

  @override
  Future<void> markRefunded(String rejectedPaymentId) async {
    final before = _rejected.length;
    _rejected.removeWhere((r) => r.id == rejectedPaymentId);
    if (_rejected.length == before) {
      throw const AppException('Ese pago ya estaba marcado como devuelto o no existe.');
    }
  }

  BandBalance _balanceOf(String bandId) {
    final c = _collected[bandId];
    final paid = _payouts.where((p) => p.bandId == bandId).fold<double>(0, (sum, p) => sum + p.amount);
    final last = _payouts.where((p) => p.bandId == bandId).map((p) => p.paidAt).fold<DateTime?>(
          null,
          (a, b) => a == null || b.isAfter(a) ? b : a,
        );
    return BandBalance(
      bandId: bandId,
      bandName: c?.name ?? 'Banda',
      collected: c?.gross ?? 0,
      netCollected: c?.net ?? 0,
      paid: paid,
      pending: (c?.net ?? 0) - paid,
      lastPayoutAt: last,
    );
  }

  @override
  Future<BandBalance> getBandBalance(String bandId) async => _balanceOf(bandId);

  @override
  Future<List<BandBalance>> getAllBalances() async =>
      _collected.keys.map(_balanceOf).toList()..sort((a, b) => b.pending.compareTo(a.pending));

  @override
  Future<List<BandPayout>> getPayouts(String bandId) async =>
      _payouts.where((p) => p.bandId == bandId).toList()..sort((a, b) => b.paidAt.compareTo(a.paidAt));

  @override
  Future<BandPayout> registerPayout({
    required String bandId,
    required double amount,
    String? reference,
    String? note,
  }) async {
    final pending = _balanceOf(bandId).pending;
    if (amount <= 0) throw const AppException('El monto tiene que ser mayor a cero.');
    if (amount > pending + 0.001) {
      throw AppException(
        'La liquidación (\$${amount.toStringAsFixed(2)}) supera el saldo pendiente '
        'de la banda (\$${pending.toStringAsFixed(2)}).',
      );
    }
    final payout = BandPayout(
      id: 'payout-${_payouts.length + 1}',
      bandId: bandId,
      amount: amount,
      reference: reference,
      note: note,
      paidAt: DateTime.now(),
    );
    _payouts.add(payout);
    return payout;
  }
}
