import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/app_user.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/config_repository.dart';
import 'package:streamtunes/repositories/donations_repository.dart';
import 'package:streamtunes/repositories/moderation_repository.dart';
import 'package:streamtunes/repositories/playlists_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/services/audio_player_service.dart';
import 'package:streamtunes/services/device_capabilities_service.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/player_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/band_public_view.dart';

void main() {
  group('Band Public View & Realtime Donations', () {
    late FakeBandsRepository bandsRepo;
    late FakeSongsRepository songsRepo;
    late FakeDonationsRepository donationsRepo;
    late BandPublicViewModel viewModel;

    const testBandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

    setUp(() {
      bandsRepo = FakeBandsRepository();
      songsRepo = FakeSongsRepository();
      donationsRepo = FakeDonationsRepository();

      viewModel = BandPublicViewModel(
        bandsRepo: bandsRepo,
        songsRepo: songsRepo,
        donationsRepo: donationsRepo,
        bandId: testBandId,
      );
    });

    tearDown(() {
      viewModel.dispose();
      donationsRepo.dispose();
    });

    test('Emisión Realtime: Stream<Donation> actualiza el muro en vivo y acumula la meta', () async {
      await viewModel.loadBandData('user-1');
      final initialTotal = viewModel.band!.donationsCollected;
      final initialCount = viewModel.recentDonations.length;

      // 1. Emitir una donación en vivo a través del stream de realtime
      final liveDonation = Donation(
        id: 'realtime-don-99',
        bandId: testBandId,
        donorName: 'Fan En Vivo',
        amountArs: 1500.0,
        message: '¡Saludos desde Quilmes!',
        createdAt: DateTime.now(),
      );

      await donationsRepo.createDonation(liveDonation);
      await pumpEventQueue();

      // 2. Verificar que el ViewModel capturó la donación del Stream
      expect(viewModel.latestLiveDonation, isNotNull);
      expect(viewModel.latestLiveDonation!.id, equals('realtime-don-99'));
      expect(viewModel.recentDonations.length, equals(initialCount + 1));
      expect(viewModel.band!.donationsCollected, equals(initialTotal + 1500.0));
    });

    test('Opt-in de Privacidad en Top 10 Fans enmascara usuarios privados como Fan anónimo', () async {
      await viewModel.loadBandData('user-1');
      final fans = viewModel.topFans;

      expect(fans.isNotEmpty, isTrue);

      // Fan 1 tiene isPublic = true
      final publicFan = fans.firstWhere((f) => f.isPublic);
      expect(publicFan.displayName, isNot('Fan anónimo'));
      expect(publicFan.avatarUrl, isNotNull);

      // Fan 2 tiene isPublic = false
      final privateFan = fans.firstWhere((f) => !f.isPublic);
      expect(privateFan.displayName, equals('Fan anónimo'));
      expect(privateFan.avatarUrl, isNull);
    });

    testWidgets('Adaptación responsive de BandPublicView (móvil vs escritorio)', (tester) async {
      final authRepo = FakeAuthRepository(
        initialUser: const AppUser(id: 'test-user', displayName: 'Test User'),
      );
      final configRepo = FakeConfigRepository();
      final playlistsRepo = FakePlaylistsRepository();
      final moderationRepo = FakeModerationRepository();
      final deviceService = DeviceCapabilitiesService();
      final audioService = AudioPlayerService();
      final pendingService = PendingFollowService();

      final sessionVM = SessionViewModel(
        authRepo: authRepo,
        bandsRepo: bandsRepo,
        configRepo: configRepo,
      );
      final playerVM = PlayerViewModel(playerService: audioService);
      final libraryVM = LibraryViewModel(
        playlistsRepo: playlistsRepo,
        bandsRepo: bandsRepo,
      );

      Widget createTestWidget() {
        return RepositoriesScope(
          authRepository: authRepo,
          bandsRepository: bandsRepo,
          songsRepository: songsRepo,
          donationsRepository: donationsRepo,
          playlistsRepository: playlistsRepo,
          moderationRepository: moderationRepo,
          configRepository: configRepo,
          deviceService: deviceService,
          audioPlayerService: audioService,
          pendingFollowService: pendingService,
          child: SessionScope(
            viewModel: sessionVM,
            child: PlayerScope(
              viewModel: playerVM,
              child: LibraryScope(
                viewModel: libraryVM,
                child: MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: const BandPublicView(bandId: testBandId),
                ),
              ),
            ),
          ),
        );
      }

      // 1. Renderizado en Pantalla Móvil (< 800px)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Los Fuzzers'), findsWidgets);
      expect(find.text('META DE RECAUDACIÓN'), findsOneWidget);

      // 2. Renderizado en Pantalla de Computadora (>= 800px)
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Los Fuzzers'), findsWidgets);
      expect(find.text('CANCIONES MÁS ESCUCHADAS'), findsOneWidget);
    });
  });
}
