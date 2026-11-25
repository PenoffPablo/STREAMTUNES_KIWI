import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/services/audio/audio_player_service.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';

/// Reproductor que falla al cargar el tema (sin conexión, archivo roto...).
class _FailingPlayer extends AudioPlayerService {
  int calls = 0;

  @override
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    calls++;
    throw Exception('Failed host lookup');
  }
}

Song _song() => Song(
      id: 's1',
      bandId: 'b1',
      title: 'Sótano',
      genre: 'Rock',
      audioPath: 'https://example.com/a.mp3',
      durationSeconds: 120,
      audioSha256: 'abc',
      createdAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('si un tema no se puede reproducir, el usuario recibe un aviso (no un error perdido)', () async {
    final service = _FailingPlayer();
    final vm = PlayerViewModel(playerService: service)..init();
    addTearDown(vm.dispose);

    final errors = <String>[];
    final sub = vm.errors.listen(errors.add);
    addTearDown(sub.cancel);

    // Igual que un toque en la UI: el Future se completa sin lanzar.
    await expectLater(vm.playSong(_song()), completes);
    await pumpEventQueue();

    expect(service.calls, 1);
    expect(errors.single, contains('No se pudo reproducir "Sótano"'));
  });

  test('un error que llega después de cerrar el reproductor no rompe nada', () async {
    final vm = PlayerViewModel(playerService: _FailingPlayer())..init();
    vm.dispose();

    await expectLater(vm.playSong(_song()), completes);
  });
}
