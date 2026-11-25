import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/services/reports/band_report_service.dart';

void main() {
  group('Isolate.run', () {
    test('BandReportService genera el CSV y la firma en otro isolate', () async {
      const service = BandReportService();
      final report = await service.generate(
        bandId: 'b1',
        bandName: 'Los "Fuzzers"',
        songs: [(title: 'A', durationSeconds: 120, playCount: 10), (title: 'B', durationSeconds: 60, playCount: 30)],
      );
      expect(report.totalPlays, 40);
      expect(report.totalMinutes, (10 * 120 + 30 * 60) ~/ 60);
      expect(report.topSongTitle, 'B');
      expect(report.csv, contains('"Los ""Fuzzers"""')); // escape CSV
      expect(report.sha256Signature, hasLength(64));
      // Determinismo: mismo input -> misma firma (calculado sin isolate).
      final again = BandReportService.buildReport(
        bandId: 'b1',
        bandName: 'Los "Fuzzers"',
        songs: [(title: 'A', durationSeconds: 120, playCount: 10), (title: 'B', durationSeconds: 60, playCount: 30)],
      );
      expect(again.sha256Signature, report.sha256Signature);
    });
  });
}
