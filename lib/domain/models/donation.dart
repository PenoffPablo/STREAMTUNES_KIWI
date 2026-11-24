class Donation {
  final String id;
  final String bandId;
  final String? donorUserId;
  final String donorName;
  final double amountArs;
  final String? message;
  final bool isAnonymous;
  final String status; // 'pending' | 'approved' | 'refunded'
  final DateTime createdAt;

  /// Lo que efectivamente recibió KIWI (descontada la comisión de Mercado Pago).
  final double? netAmount;

  /// Id del pago en Mercado Pago. Si está, el pago fue verificado por el webhook.
  final String? mpPaymentId;

  /// Nombre de la banda (viene del join con `bands`, para listados de moderación).
  final String? bandName;

  const Donation({
    required this.id,
    required this.bandId,
    this.donorUserId,
    required this.donorName,
    required this.amountArs,
    this.message,
    this.isAnonymous = false,
    this.status = 'approved',
    required this.createdAt,
    this.netAmount,
    this.mpPaymentId,
    this.bandName,
  });

  bool get isApproved => status == 'approved';

  /// Pago confirmado contra la API de Mercado Pago (cuenta para liquidar).
  bool get isVerified => mpPaymentId != null && mpPaymentId!.isNotEmpty;

  /// Neto si se conoce; si no, el bruto.
  double get netOrAmount => netAmount ?? amountArs;

  Donation copyWith({
    String? id,
    String? bandId,
    String? donorUserId,
    String? donorName,
    double? amountArs,
    String? message,
    bool? isAnonymous,
    String? status,
    DateTime? createdAt,
    double? netAmount,
    String? mpPaymentId,
    String? bandName,
  }) {
    return Donation(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      donorUserId: donorUserId ?? this.donorUserId,
      donorName: donorName ?? this.donorName,
      amountArs: amountArs ?? this.amountArs,
      message: message ?? this.message,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      netAmount: netAmount ?? this.netAmount,
      mpPaymentId: mpPaymentId ?? this.mpPaymentId,
      bandName: bandName ?? this.bandName,
    );
  }

  /// Columnas de `public.donations`. El público solo puede leer las no
  /// sensibles: `donor_name` (NULL si el aporte es anónimo, lo arma la base),
  /// monto, mensaje y fecha. `donor_id`, `net_amount` y `mp_payment_id` solo
  /// llegan por la RPC de moderación `admin_recent_payments` (con `band_name`).
  factory Donation.fromJson(Map<String, dynamic> json) {
    final isPublic = json['is_public'] as bool? ?? true;
    final donorName = json['donor_name'] as String?;

    return Donation(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      donorUserId: json['donor_id'] as String?,
      donorName: !isPublic ? 'Fan anónimo' : (donorName ?? 'Fan de la banda'),
      amountArs: (json['amount'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
      isAnonymous: !isPublic,
      status: json['status'] as String? ?? 'approved',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      netAmount: (json['net_amount'] as num?)?.toDouble(),
      mpPaymentId: json['mp_payment_id'] as String?,
      bandName: json['band_name'] as String?,
    );
  }
}
