import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/config/dependencies.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/data/services/audio/audio_player_service.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/band_public/view_models/band_public_view_model.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/band_public/widgets/band_public_view.dart';

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
      await viewModel.init(currentUserId: 'user-1');
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

      // Pago aprobado (lo que hace el webhook de Mercado Pago): entra al muro.
      donationsRepo.addApproved(liveDonation);
      await pumpEventQueue();

      // 2. Verificar que el ViewModel capturó la donación del Stream
      expect(viewModel.latestLiveDonation, isNotNull);
      expect(viewModel.latestLiveDonation!.id, equals('realtime-don-99'));
      expect(viewModel.recentDonations.length, equals(initialCount + 1));
      expect(viewModel.band!.donationsCollected, equals(initialTotal + 1500.0));
    });

    test('Opt-in de Privacidad en Top 10 Fans enmascara usuarios privados como Fan anónimo', () async {
      await viewModel.init(currentUserId: 'user-1');
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

      final sessionVM = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);
      final playerVM = PlayerViewModel(playerService: audioService);
      final libraryVM = LibraryViewModel(playlistsRepo: playlistsRepo, bandsRepo: bandsRepo);

      Widget createTestWidget() {
        return DependenciesScope(
          dependencies: AppDependencies.fake(
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
          ),
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
