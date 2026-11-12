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
  });

  bool get isApproved => status == 'approved';

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
    );
  }

  factory Donation.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount_ars'] ?? json['amount'];
    final isAnon = json['is_anonymous'] as bool? ??
        (json.containsKey('is_public') ? !(json['is_public'] as bool? ?? true) : false);

    return Donation(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      donorUserId: (json['donor_user_id'] ?? json['donor_id']) as String?,
      donorName: json['donor_name'] as String? ?? (isAnon ? 'Fan anónimo' : 'Fan'),
      amountArs: (rawAmount as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
      isAnonymous: isAnon,
      status: json['status'] as String? ?? 'approved',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'band_id': bandId,
      'donor_user_id': donorUserId,
      'donor_name': donorName,
      'amount_ars': amountArs,
      'message': message,
      'is_anonymous': isAnonymous,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

