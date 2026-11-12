class BandPhoto {
  final String id;
  final String bandId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  const BandPhoto({
    required this.id,
    required this.bandId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  BandPhoto copyWith({
    String? id,
    String? bandId,
    String? photoUrl,
    String? caption,
    DateTime? createdAt,
  }) {
    return BandPhoto(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      photoUrl: photoUrl ?? this.photoUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BandPhoto.fromJson(Map<String, dynamic> json) {
    return BandPhoto(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'band_id': bandId,
      'photo_url': photoUrl,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

