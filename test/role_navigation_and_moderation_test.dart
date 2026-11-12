import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:streamtunes/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/player_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/navigation_shell.dart';

void main() {
  group('Role Navigation & Moderation Tests (Criterios B1, C1, F1)', () {
    late FakeAuthRepository authRepo;
    late FakeBandsRepository bandsRepo;
    late FakeSongsRepository songsRepo;
    late FakeDonationsRepository donationsRepo;
    late FakePlaylistsRepository playlistsRepo;
    late FakeModerationRepository moderationRepo;
    late FakeConfigRepository configRepo;
    late DeviceCapabilitiesService deviceService;
    late AudioPlayerService audioService;
    late PendingFollowService pendingService;

    setUp(() {
      authRepo = FakeAuthRepository();
      bandsRepo = FakeBandsRepository();
      songsRepo = FakeSongsRepository();
      donationsRepo = FakeDonationsRepository();
      playlistsRepo = FakePlaylistsRepository();
      moderationRepo = FakeModerationRepository();
      configRepo = FakeConfigRepository();
      deviceService = DeviceCapabilitiesService();
      audioService = AudioPlayerService();
      pendingService = PendingFollowService();
    });

    tearDown(() {
      audioService.dispose();
      authRepo.dispose();
      donationsRepo.dispose();
    });

    Widget createNavigationWidget(SessionViewModel sessionVM) {
      final playerVM = PlayerViewModel(playerService: audioService);
      final libraryVM = LibraryViewModel(
        playlistsRepo: playlistsRepo,
        bandsRepo: bandsRepo,
      );

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
                home: const NavigationShell(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Visitante anónimo ve únicamente 2 pestañas (Inicio, Cuenta)', (tester) async {
      final sessionVM = SessionViewModel(
        authRepo: authRepo,
        bandsRepo: bandsRepo,
        configRepo: configRepo,
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget(sessionVM));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Cuenta'), findsWidgets);
      expect(find.text('Biblioteca'), findsNothing);
      expect(find.text('Subir'), findsNothing);
      expect(find.text('Mi Banda'), findsNothing);
    });

    testWidgets('Oyente registrado ve 3 pestañas (Inicio, Biblioteca, Cuenta)', (tester) async {
      await authRepo.signInWithEmail('fan@correo.com', 'pass123');

      final sessionVM = SessionViewModel(
        authRepo: authRepo,
        bandsRepo: bandsRepo,
        configRepo: configRepo,
      );
      await sessionVM.signInWithEmail('fan@correo.com', 'pass123');

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget(sessionVM));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Biblioteca'), findsWidgets);
      expect(find.text('Cuenta'), findsWidgets);
      expect(find.text('Subir'), findsNothing);
      expect(find.text('Mi Banda'), findsNothing);
    });

    testWidgets('Músico con banda activa ve 5 pestañas (Inicio, Subir, Biblioteca, Mi Banda, Cuenta)', (tester) async {
      final sessionVM = SessionViewModel(
        authRepo: authRepo,
        bandsRepo: bandsRepo,
        configRepo: configRepo,
      );
      // Usuario músico con banda
      await sessionVM.signInWithEmail('artist@fuzz.com', 'pass123');

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget(sessionVM));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Subir'), findsWidgets);
      expect(find.text('Biblioteca'), findsWidgets);
      expect(find.text('Mi Banda'), findsWidgets);
      expect(find.text('Cuenta'), findsWidgets);
    });

    test('Flujo de moderación completo: Banda pending aprobada por moderador y reporte resuelto', () async {
      final modVM = AdminModerationViewModel(
        moderationRepo: moderationRepo,
        configRepo: configRepo,
      );

      // 1. Cargar datos iniciales
      await modVM.loadModerationData();
      expect(modVM.pendingBands.isNotEmpty, isTrue);
      expect(modVM.openReports.isNotEmpty, isTrue);

      final pendingBandId = modVM.pendingBands.first.id;

      // 2. Moderador aprueba la banda
      await modVM.approveBand(pendingBandId);

      // 3. La banda ya no figura como pendiente
      expect(modVM.pendingBands.any((b) => b.id == pendingBandId), isFalse);

      // 4. Moderador resuelve el reporte de infracción de copyright
      final reportId = modVM.openReports.first.id;
      await modVM.resolveReport(reportId, hideSong: true);

      // 5. El reporte queda cerrado
      expect(modVM.openReports.any((r) => r.id == reportId), isFalse);

      modVM.dispose();
    });
  });
}
