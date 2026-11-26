import 'dart:isolate';

import 'package:streamtunes/domain/models/band_daily_report.dart';

/// Fila de entrada del cálculo. Solo datos primitivos: es lo que se copia al
/// otro isolate (nada de repositorios, clientes HTTP ni ChangeNotifiers).
typedef MetricsSongRow = ({String title, int durationSeconds, int playCount});

/// Calcula el reporte diario de una banda en un isolate aparte, para no
/// trabar la interfaz con muchos temas.
class BandMetricsService {
  const BandMetricsService();

  Future<BandDailyReport> compute(List<MetricsSongRow> songs) {
    // La clausura de Isolate.run solo captura esta lista local inmutable. Si
    // usara campos de un objeto, Dart intentaría copiar el objeto entero.
    final rows = List<MetricsSongRow>.unmodifiable(songs);
    return Isolate.run(() => buildReport(rows));
  }

  /// Trabajo pesado (CPU): ordenar, agregar y calcular porcentajes.
  /// Es estático y puro para poder testearlo sin isolates.
  static BandDailyReport buildReport(List<MetricsSongRow> songs) {
    final sorted = [...songs]..sort((a, b) => b.playCount.compareTo(a.playCount));
    final totalPlays = sorted.fold<int>(0, (sum, s) => sum + s.playCount);
    var totalSeconds = 0;
    var withoutPlays = 0;

    final performance = <SongPerformance>[];
    for (final s in sorted) {
      final listenedSeconds = s.playCount * s.durationSeconds;
      totalSeconds += listenedSeconds;
      if (s.playCount == 0) withoutPlays++;
      performance.add(SongPerformance(
        title: s.title,
        plays: s.playCount,
        minutesListened: listenedSeconds ~/ 60,
        sharePct: totalPlays == 0 ? 0 : s.playCount * 100 / totalPlays,
      ));
    }

    return BandDailyReport(
      songs: performance,
      totalPlays: totalPlays,
      totalMinutes: totalSeconds ~/ 60,
      averagePlaysPerSong: sorted.isEmpty ? 0 : totalPlays / sorted.length,
      songsWithoutPlays: withoutPlays,
      generatedAt: DateTime.now(),
    );
  }
}
