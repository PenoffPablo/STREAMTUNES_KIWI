class SongReport {
  final String id;
  final String songId;
  final String reporterUserId;
  final String reason;
  final String status; // 'open' | 'resolved' | 'dismissed'
  final DateTime createdAt;
  final String? songTitle;
  final String? bandName;

  const SongReport({
    required this.id,
    required this.songId,
    required this.reporterUserId,
    required this.reason,
    this.status = 'open',
    required this.createdAt,
    this.songTitle,
    this.bandName,
  });

  bool get isOpen => status == 'open';

  SongReport copyWith({
    String? id,
    String? songId,
    String? reporterUserId,
    String? reason,
    String? status,
    DateTime? createdAt,
    String? songTitle,
    String? bandName,
  }) {
    return SongReport(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      songTitle: songTitle ?? this.songTitle,
      bandName: bandName ?? this.bandName,
    );
  }

  factory SongReport.fromJson(Map<String, dynamic> json, {String? songTitle, String? bandName}) {
    return SongReport(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      songTitle: songTitle ?? json['songs']?['title'] as String?,
      bandName: bandName ?? json['songs']?['bands']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song_id': songId,
      'reporter_user_id': reporterUserId,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

