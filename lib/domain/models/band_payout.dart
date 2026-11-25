/// Pago que KIWI le hizo a una banda (liquidación de los aportes recaudados).
class BandPayout {
  final String id;
  final String bandId;
  final double amount;

  /// Número de operación o comprobante de la transferencia de Mercado Pago.
  final String? reference;
  final String? note;
  final DateTime paidAt;

  const BandPayout({
    required this.id,
    required this.bandId,
    required this.amount,
    this.reference,
    this.note,
    required this.paidAt,
  });

  factory BandPayout.fromJson(Map<String, dynamic> json) => BandPayout(
        id: json['id'] as String,
        bandId: json['band_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        reference: json['reference'] as String?,
        note: json['note'] as String?,
        paidAt: DateTime.parse(json['paid_at'] as String),
      );
}

/// Estado de cuenta de una banda con KIWI.
///
/// KIWI cobra todos los aportes en su cuenta de Mercado Pago y después le
/// transfiere a cada banda lo que le corresponde.
class BandBalance {
  final String bandId;
  final String bandName;

  /// Total que pagaron los fans (bruto), solo pagos verificados por MP.
  final double collected;

  /// Lo que efectivamente recibió KIWI, descontada la comisión de MP.
  final double netCollected;

  /// Comisión de KIWI (20% del neto) para sostener la app. Ya está descontada
  /// de [pending].
  final double kiwiFee;

  /// Lo que KIWI ya le transfirió a la banda.
  final double paid;

  /// Saldo a favor de la banda: neto - comisión KIWI - liquidado.
  final double pending;

  final DateTime? lastPayoutAt;

  const BandBalance({
    required this.bandId,
    required this.bandName,
    required this.collected,
    required this.netCollected,
    this.kiwiFee = 0,
    required this.paid,
    required this.pending,
    this.lastPayoutAt,
  });

  double get mercadoPagoFees => collected - netCollected;

  /// Lo que le corresponde a la banda en total (cobrado o no).
  double get bandShare => netCollected - kiwiFee;
  bool get hasPending => pending > 0.009;

  factory BandBalance.fromJson(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0;
    final last = json['last_payout_at'] as String?;
    return BandBalance(
      bandId: json['band_id'] as String,
      bandName: json['band_name'] as String? ?? 'Banda',
      collected: n('collected'),
      netCollected: n('net_collected'),
      kiwiFee: n('kiwi_fee'),
      paid: n('paid'),
      pending: n('pending'),
      lastPayoutAt: last != null ? DateTime.parse(last) : null,
    );
  }

  static BandBalance empty(String bandId, {String bandName = 'Banda'}) => BandBalance(
        bandId: bandId,
        bandName: bandName,
        collected: 0,
        netCollected: 0,
        paid: 0,
        pending: 0,
      );
}

/// Pago que Mercado Pago aprobó (la plata está en la cuenta de KIWI) pero que
/// no se pudo registrar como aporte: banda suspendida, monto mayor al tope o
/// pago sin banda. Un moderador tiene que devolverlo al fan.
class RejectedPayment {
  const RejectedPayment({
    required this.id,
    required this.mpPaymentId,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.bandName,
  });

  final String id;
  final String mpPaymentId;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final String? bandName;

  factory RejectedPayment.fromJson(Map<String, dynamic> json) {
    final band = json['band'];
    return RejectedPayment(
      id: json['id'] as String,
      mpPaymentId: json['mp_payment_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      bandName: band is Map ? band['name'] as String? : null,
    );
  }
}
