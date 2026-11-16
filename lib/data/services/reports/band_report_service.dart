import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';

/// Fila de entrada del reporte. Solo datos primitivos: es lo que se copia al
/// otro isolate (nada de repositorios, clientes HTTP ni ChangeNotifiers).
typedef ReportSongRow = ({String title, int durationSeconds, int playCount});

/// Resultado del reporte generado en segundo plano.
class BandReport {
  final String csv;
  final String sha256Signature;
  final int totalPlays;
  final int totalMinutes;
  final String? topSongTitle;
  final DateTime generatedAt;

  const BandReport({
    required this.csv,
    required this.sha256Signature,
    required this.totalPlays,
    required this.totalMinutes,
    required this.topSongTitle,
    required this.generatedAt,
  });

  String get summary => [
        '=== REPORTE INDEPENDIENTE STREAMTUNES ===',
        'Generado: ${generatedAt.toIso8601String()}',
        'Reproducciones totales: $totalPlays',
        'Minutos escuchados (estimado): $totalMinutes',
        if (topSongTitle != null) 'Tema más escuchado: $topSongTitle',
        'Firma SHA-256 del CSV: $sha256Signature',
      ].join('\n');
}

/// Genera el historial exportable de una banda en un isolate aparte.
class BandReportService {
  const BandReportService();

  Future<BandReport> generate({
    required String bandId,
    required String bandName,
    required List<ReportSongRow> songs,
  }) {
    // IMPORTANTE: la clausura de Isolate.run solo captura estas variables
    // locales inmutables. Si usáramos campos de un objeto (`this.bandId`),
    // Dart intentaría copiar el objeto entero al otro isolate y fallaría.
    final rows = List<ReportSongRow>.unmodifiable(songs);
    return Isolate.run(() => buildReport(bandId: bandId, bandName: bandName, songs: rows));
  }

  /// Trabajo pesado (CPU): ordenar, agregar, generar CSV y firmarlo.
  /// Es estático y puro para poder testearlo sin isolates.
  static BandReport buildReport({
    required String bandId,
    required String bandName,
    required List<ReportSongRow> songs,
  }) {
    final sorted = [...songs]..sort((a, b) => b.playCount.compareTo(a.playCount));
    var totalPlays = 0;
    var totalSeconds = 0;

    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final csv = StringBuffer('banda,tema,duracion_seg,reproducciones,minutos_escuchados\n');
    for (final s in sorted) {
      final listenedSeconds = s.playCount * s.durationSeconds;
      totalPlays += s.playCount;
      totalSeconds += listenedSeconds;
      csv.writeln('${esc(bandName)},${esc(s.title)},${s.durationSeconds},'
          '${s.playCount},${(listenedSeconds / 60).toStringAsFixed(1)}');
    }

    final csvText = csv.toString();
    return BandReport(
      csv: csvText,
      sha256Signature: sha256.convert(utf8.encode('$bandId\n$csvText')).toString(),
      totalPlays: totalPlays,
      totalMinutes: totalSeconds ~/ 60,
      topSongTitle: sorted.isEmpty ? null : sorted.first.title,
      generatedAt: DateTime.now(),
    );
  }
}
