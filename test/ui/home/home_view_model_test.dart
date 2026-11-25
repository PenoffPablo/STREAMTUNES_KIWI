import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/home/view_models/home_view_model.dart';

/// Repositorio de canciones con latencia controlable, para probar carreras.
class _SlowSongsRepository extends FakeSongsRepository {
  /// Compuertas por GÉNERO: permiten demorar una petición y dejar pasar otra.
  final Map<String?, Completer<void>> gates = {};
  final List<String?> queries = [];

  @override
  Future<List<Song>> getLatestSongs({int limit = 20, String? genre, String? query}) async {
    queries.add(query);
    final gate = gates[genre];
    if (gate != null) await gate.future;
    return super.getLatestSongs(limit: limit, genre: genre, query: query);
  }
}

void main() {
  group('HomeViewModel: búsqueda (Streams)', () {
    test('HomeViewModel: búsqueda con debounce hace UNA consulta por ráfaga', () async {
      final songs = _SlowSongsRepository();
      final vm = HomeViewModel(
        songsRepo: songs,
        bandsRepo: FakeBandsRepository(),
        authRepo: FakeAuthRepository(),
        pendingFollowService: PendingFollowService(),
        searchDebounce: const Duration(milliseconds: 20),
      );
      await vm.init();
      songs.queries.clear();

      for (final q in ['n', 'no', 'noc', 'noches']) {
        vm.search(q);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(songs.queries, ['noches']);
      vm.dispose();
    });

    test('HomeViewModel: "la última petición gana" descarta respuestas viejas', () async {
      final songs = _SlowSongsRepository();
      final vm = HomeViewModel(
        songsRepo: songs,
        bandsRepo: FakeBandsRepository(),
        authRepo: FakeAuthRepository(),
        pendingFollowService: PendingFollowService(),
        searchDebounce: Duration.zero,
      );
      await vm.init();

      final allSongs = vm.latestSongs; // resultado de "Todos"
      final slowGate = songs.gates[null] = Completer<void>(); // "Todos" va a tardar
      final oldRequest = vm.loadFeed(); // petición vieja (Todos), queda colgada
      vm.setGenre('Jazz'); // petición nueva, responde enseguida
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final jazzResult = vm.latestSongs;
      expect(jazzResult.length, isNot(allSongs.length), reason: 'los dos resultados deben diferir');

      slowGate.complete(); // ahora responde la vieja...
      await oldRequest;
      expect(vm.latestSongs, jazzResult, reason: '...pero NO pisa el resultado nuevo');
      expect(vm.selectedGenre, 'Jazz');
      vm.dispose();
    });
  });
}
