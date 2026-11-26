import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/services/reports/band_metrics_service.dart';

void main() {
  group('Isolate.run', () {
    test('BandMetricsService calcula el desglose por tema en otro isolate', () async {
      const service = BandMetricsService();
      final report = await service.compute([
        (title: 'A', durationSeconds: 120, playCount: 10),
        (title: 'B', durationSeconds: 60, playCount: 30),
        (title: 'C', durationSeconds: 200, playCount: 0),
      ]);

      expect(report.totalPlays, 40);
      expect(report.totalMinutes, (10 * 120 + 30 * 60) ~/ 60);
      expect(report.songs.map((s) => s.title), ['B', 'A', 'C'], reason: 'de más a menos escuchado');
      expect(report.songs.first.sharePct, 75);
      expect(report.songs.first.minutesListened, 30);
      expect(report.topSong!.title, 'B');
      expect(report.songsWithoutPlays, 1);
      expect(report.averagePlaysPerSong, closeTo(13.33, 0.01));
    });

    test('una banda sin temas o sin escuchas no divide por cero', () {
      final empty = BandMetricsService.buildReport([]);
      expect(empty.totalPlays, 0);
      expect(empty.averagePlaysPerSong, 0);
      expect(empty.topSong, isNull);

      final silent = BandMetricsService.buildReport([(title: 'A', durationSeconds: 90, playCount: 0)]);
      expect(silent.songs.single.sharePct, 0);
      expect(silent.topSong, isNull);
    });
  });
}
