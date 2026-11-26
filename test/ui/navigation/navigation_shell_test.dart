import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/navigation/widgets/navigation_shell.dart';

void main() {
  group('Role Navigation & Moderation Tests', () {
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
      final libraryVM = LibraryViewModel(playlistsRepo: playlistsRepo, bandsRepo: bandsRepo);

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
              child: MaterialApp(theme: AppTheme.darkTheme, home: const NavigationShell()),
            ),
          ),
        ),
      );
    }

    testWidgets('Visitante anónimo ve únicamente 2 pestañas (Inicio, Cuenta)', (tester) async {
      final sessionVM = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);

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

      final sessionVM = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);
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
      final sessionVM = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);
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
      final modVM = AdminModerationViewModel(moderationRepo: moderationRepo, configRepo: configRepo);

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

    testWidgets('si la sesión vence, cierra lo abierto y lleva al inicio de sesión con un aviso', (tester) async {
      final sessionVM = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);
      await sessionVM.init();
      await sessionVM.signInWithEmail('fan@correo.com', 'pass123');

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationWidget(sessionVM));
      await tester.pumpAndSettle();

      // Está en Biblioteca con una pantalla encima (como el panel de admin).
      await tester.tap(find.text('Biblioteca').last);
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Pantalla abierta')))));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla abierta'), findsOneWidget);

      authRepo.expireSession();
      await tester.pumpAndSettle();

      expect(find.text('Pantalla abierta'), findsNothing, reason: 'se cierran las pantallas abiertas');
      expect(find.text('Iniciar Sesión'), findsOneWidget, reason: 'queda en Cuenta, en el formulario de ingreso');
      expect(find.textContaining('Tu sesión venció'), findsWidgets);
      expect(sessionVM.currentUser, isNull);
    });
  });
}
