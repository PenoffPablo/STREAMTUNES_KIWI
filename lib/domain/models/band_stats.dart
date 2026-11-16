class TopSongStat {
  final String id;
  final String title;
  final int durationSeconds;
  final int playCount;
  final int recentPlays;

  const TopSongStat({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.playCount,
    this.recentPlays = 0,
  });

  factory TopSongStat.fromJson(Map<String, dynamic> json) {
    return TopSongStat(
      id: json['id'] as String,
      title: json['title'] as String,
      durationSeconds: (json['duration_s'] as num?)?.toInt() ?? 0,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      recentPlays: (json['recent_plays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration_s': durationSeconds,
      'play_count': playCount,
      'recent_plays': recentPlays,
    };
  }
}

class BandAggregatedStats {
  final String bandId;
  final int totalPlays;
  final int totalMinutes;
  final int last7DaysPlays;
  final List<TopSongStat> topSongs;

  const BandAggregatedStats({
    required this.bandId,
    required this.totalPlays,
    required this.totalMinutes,
    required this.last7DaysPlays,
    required this.topSongs,
  });

  factory BandAggregatedStats.fromJson(Map<String, dynamic> json) {
    final topSongsList = (json['top_songs'] as List?)
            ?.map((e) => TopSongStat.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return BandAggregatedStats(
      bandId: json['band_id'] as String? ?? '',
      totalPlays: (json['total_plays'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      last7DaysPlays: (json['last_7_days_plays'] as num?)?.toInt() ?? 0,
      topSongs: topSongsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'band_id': bandId,
      'total_plays': totalPlays,
      'total_minutes': totalMinutes,
      'last_7_days_plays': last7DaysPlays,
      'top_songs': topSongs.map((e) => e.toJson()).toList(),
    };
  }
}

class TopFanStat {
  final int rank;
  final String? userId;
  final String displayName;
  final String? avatarUrl;
  final int minutesListened;
  final bool isPublic;

  const TopFanStat({
    required this.rank,
    this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.minutesListened,
    required this.isPublic,
  });

  factory TopFanStat.fromJson(Map<String, dynamic> json) {
    return TopFanStat(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String? ?? 'Fan anónimo',
      avatarUrl: json['avatar_url'] as String?,
      minutesListened: (json['minutes_listened'] as num?)?.toInt() ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'minutes_listened': minutesListened,
      'is_public': isPublic,
    };
  }
}

