class Album {
  final String id;
  final String bandId;
  final String title;
  final int? releaseYear;
  final String? coverUrl;
  final DateTime createdAt;

  const Album({
    required this.id,
    required this.bandId,
    required this.title,
    this.releaseYear,
    this.coverUrl,
    required this.createdAt,
  });

  Album copyWith({
    String? id,
    String? bandId,
    String? title,
    int? releaseYear,
    String? coverUrl,
    DateTime? createdAt,
  }) {
    return Album(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      title: title ?? this.title,
      releaseYear: releaseYear ?? this.releaseYear,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      title: json['title'] as String,
      releaseYear: (json['release_year'] as num?)?.toInt(),
      coverUrl: json['cover_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'band_id': bandId,
      'title': title,
      'release_year': releaseYear,
      'cover_url': coverUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

