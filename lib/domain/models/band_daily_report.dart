/// Rendimiento de un tema dentro del reporte diario de la banda.
class SongPerformance {
  final String title;
  final int plays;

  /// Minutos escuchados estimados: reproducciones × duración del tema.
  final int minutesListened;

  /// Porcentaje de las reproducciones totales de la banda (0 a 100).
  final double sharePct;

  const SongPerformance({
    required this.title,
    required this.plays,
    required this.minutesListened,
    required this.sharePct,
  });

  factory SongPerformance.fromJson(Map<String, dynamic> json) => SongPerformance(
        title: json['title'] as String? ?? '',
        plays: (json['plays'] as num?)?.toInt() ?? 0,
        minutesListened: (json['minutes'] as num?)?.toInt() ?? 0,
        sharePct: (json['share_pct'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'plays': plays,
        'minutes': minutesListened,
        'share_pct': sharePct,
      };
}

/// Reporte del día de una banda, calculado en un isolate a partir de sus
/// temas. Se muestra en el panel (no se exporta).
class BandDailyReport {
  /// Temas ordenados de más a menos escuchado.
  final List<SongPerformance> songs;
  final int totalPlays;
  final int totalMinutes;
  final double averagePlaysPerSong;
  final int songsWithoutPlays;
  final DateTime generatedAt;

  const BandDailyReport({
    required this.songs,
    required this.totalPlays,
    required this.totalMinutes,
    required this.averagePlaysPerSong,
    required this.songsWithoutPlays,
    required this.generatedAt,
  });

  SongPerformance? get topSong => songs.isEmpty || songs.first.plays == 0 ? null : songs.first;

  factory BandDailyReport.fromJson(Map<String, dynamic> json) => BandDailyReport(
        songs: [
          for (final s in (json['songs'] as List? ?? const []))
            SongPerformance.fromJson(s as Map<String, dynamic>),
        ],
        totalPlays: (json['total_plays'] as num?)?.toInt() ?? 0,
        totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
        averagePlaysPerSong: (json['average_plays'] as num?)?.toDouble() ?? 0,
        songsWithoutPlays: (json['songs_without_plays'] as num?)?.toInt() ?? 0,
        generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'songs': songs.map((s) => s.toJson()).toList(),
        'total_plays': totalPlays,
        'total_minutes': totalMinutes,
        'average_plays': averagePlaysPerSong,
        'songs_without_plays': songsWithoutPlays,
        'generated_at': generatedAt.toIso8601String(),
      };
}
