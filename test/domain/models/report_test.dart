import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/domain/models/report.dart';

void main() {
  test('un reporte sobre una BANDA (sin canción) se lee sin romper el panel', () {
    // Así llega de la base: song_id vacío y la columna se llama reporter_id.
    final r = SongReport.fromJson({
      'id': 'r1',
      'reporter_id': 'u1',
      'band_id': 'b1',
      'song_id': null,
      'reason': 'Revisar si es música propia.',
      'status': 'open',
      'created_at': '2026-11-09T22:36:05.886318+00:00',
      'songs': null,
      'bands': {'name': 'Los Fuzzers'},
    });
    expect(r.isAboutSong, isFalse);
    expect(r.bandId, 'b1');
    expect(r.reporterUserId, 'u1');
    expect(r.bandName, 'Los Fuzzers');
  });

  test('un reporte sobre una canción trae la canción y su banda', () {
    final r = SongReport.fromJson({
      'id': 'r2',
      'reporter_id': 'u1',
      'band_id': null,
      'song_id': 's1',
      'reason': 'No es música propia.',
      'status': 'open',
      'created_at': '2026-11-26T10:00:00Z',
      'songs': {'title': 'Sótano', 'bands': {'name': 'Los Fuzzers'}},
      'bands': null,
    });
    expect(r.isAboutSong, isTrue);
    expect(r.songTitle, 'Sótano');
    expect(r.bandName, 'Los Fuzzers');
  });
}
