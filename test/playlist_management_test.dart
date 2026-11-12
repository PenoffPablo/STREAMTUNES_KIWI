import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/playlists_repository.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/services/audio_player_service.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/player_view_model.dart';
import 'package:streamtunes/views/playlist_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playlist Management & Detail Tests', () {
    late FakePlaylistsRepository playlistsRepo;
    late FakeBandsRepository bandsRepo;
    late AudioPlayerService audioService;
    late LibraryViewModel libraryVM;
    late PlayerViewModel playerVM;

    setUp(() {
      playlistsRepo = FakePlaylistsRepository();
      bandsRepo = FakeBandsRepository();
      audioService = AudioPlayerService();
      libraryVM = LibraryViewModel(
        playlistsRepo: playlistsRepo,
        bandsRepo: bandsRepo,
      );
      playerVM = PlayerViewModel(playerService: audioService);
    });

    tearDown(() {
      audioService.dispose();
    });

    test('LibraryViewModel: Agrega y quita canciones invalidando cache', () async {
      final pl = await libraryVM.createPlaylist('user-1', 'Mi Lista de Prueba');
      expect(pl, isNotNull);

      // Agregar canción
      final added = await libraryVM.addSongToPlaylist(pl!.id, 'song-abc');
      expect(added, isTrue);

      final songs1 = await libraryVM.getSongsForPlaylist(pl.id);
      expect(songs1.length, 1);
      expect(songs1.first.id, 'song-abc');

      // Quitar canción
      final removed = await libraryVM.removeSongFromPlaylist(pl.id, 'song-abc');
      expect(removed, isTrue);

      final songs2 = await libraryVM.getSongsForPlaylist(pl.id, forceRefresh: true);
      expect(songs2.isEmpty, isTrue);
    });

    testWidgets('PlaylistDetailView: Renderiza cabecera, controles de orden/aleatorio y lista', (tester) async {
      final playlist = Playlist(
        id: 'pl-test',
        userId: 'user-1',
        title: 'Grandes Éxitos',
        songIds: ['song-1', 'song-2'],
        createdAt: DateTime.now(),
      );

      // Precargar en fake repo
      await playlistsRepo.addSongToPlaylist(playlist.id, 'song-1');
      await playlistsRepo.addSongToPlaylist(playlist.id, 'song-2');

      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScope(
            viewModel: playerVM,
            child: LibraryScope(
              viewModel: libraryVM,
              child: PlaylistDetailView(playlist: playlist),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que muestra el título y botones de reproducción
      expect(find.text('Grandes Éxitos'), findsWidgets);
      expect(find.text('En orden'), findsOneWidget);
      expect(find.text('Aleatorio'), findsOneWidget);

      // Verificar que los botones son clickeables
      await tester.tap(find.text('En orden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aleatorio'));
      await tester.pumpAndSettle();
    });
  });
}

