import 'package:streamtunes/domain/models/band_payout.dart';

/// Liquidaciones: lo que KIWI le transfiere a cada banda de los aportes que
/// cobró en su cuenta de Mercado Pago.
abstract class PayoutsRepository {
  /// Estado de cuenta de una banda (la ven sus miembros y los moderadores).
  Future<BandBalance> getBandBalance(String bandId);

  /// Estado de cuenta de todas las bandas, mayor saldo primero (solo moderadores).
  Future<List<BandBalance>> getAllBalances();

  /// Historial de pagos a una banda, más reciente primero.
  Future<List<BandPayout>> getPayouts(String bandId);

  /// Registra un pago de KIWI a la banda (solo moderadores). Falla si supera
  /// el saldo pendiente.
  Future<BandPayout> registerPayout({
    required String bandId,
    required double amount,
    String? reference,
    String? note,
  });

  /// Pagos aprobados por Mercado Pago que no se pudieron registrar como
  /// aporte y todavía no se devolvieron (solo moderadores).
  Future<List<RejectedPayment>> getPendingRefunds();

  /// Marca que el moderador ya devolvió el pago desde Mercado Pago.
  Future<void> markRefunded(String rejectedPaymentId);
}
