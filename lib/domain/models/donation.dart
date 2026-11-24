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

  /// Columnas reales de `public.donations`: donor_id, amount, net_amount,
  /// mp_payment_id, currency, is_public, status. El nombre del donante NO se
  /// guarda en la tabla: viene del join con `profiles` (alias `donor`) y se
  /// oculta si la donación es anónima. La banda, del join con `bands` (alias `band`).
  factory Donation.fromJson(Map<String, dynamic> json) {
    final isPublic = json['is_public'] as bool? ?? true;
    final profile = json['donor'];
    final profileName = profile is Map ? profile['display_name'] as String? : null;
    final band = json['band'];

    return Donation(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      donorUserId: json['donor_id'] as String?,
      donorName: !isPublic ? 'Fan anónimo' : (profileName ?? 'Fan de la banda'),
      amountArs: (json['amount'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
      isAnonymous: !isPublic,
      status: json['status'] as String? ?? 'approved',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      netAmount: (json['net_amount'] as num?)?.toDouble(),
      mpPaymentId: json['mp_payment_id'] as String?,
      bandName: band is Map ? band['name'] as String? : null,
    );
  }

  /// Fila con las columnas reales de `public.donations`.
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'band_id': bandId,
      'donor_id': donorUserId,
      'amount': amountArs,
      'currency': 'ARS',
      'message': message,
      'is_public': !isAnonymous,
      'status': status,
    };
  }
}
