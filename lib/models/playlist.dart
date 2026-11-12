class Playlist {
  final String id;
  final String userId;
  final String title;
  final List<String> songIds;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.userId,
    required this.title,
    this.songIds = const [],
    required this.createdAt,
  });

  Playlist copyWith({
    String? id,
    String? userId,
    String? title,
    List<String>? songIds,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json, {List<String>? songIds}) {
    return Playlist(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: (json['title'] ?? json['name'] ?? 'Mi Playlist') as String,
      songIds: songIds ??
          (json['playlist_songs'] as List?)
              ?.map((e) => (e['song_id'] ?? e) as String)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

