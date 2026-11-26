import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_supabase.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_supabase.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_supabase.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository_fake.dart';
import 'package:streamtunes/data/repositories/device_tokens/device_tokens_repository_supabase.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_supabase.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_supabase.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository_fake.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository_supabase.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_supabase.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository_fake.dart';
import 'package:streamtunes/data/repositories/playlists/playlists_repository_supabase.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_supabase.dart';
import 'package:streamtunes/data/services/audio/audio_analyzer_service.dart';
import 'package:streamtunes/data/services/audio/audio_player_service.dart';
import 'package:streamtunes/data/services/device/deep_link_service.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/data/services/notifications/background_upload_service.dart';
import 'package:streamtunes/data/services/notifications/push_notification_service.dart';
import 'package:streamtunes/data/services/reports/band_metrics_service.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/ui/band_registration/view_models/band_registration_view_model.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/band_public/view_models/band_public_view_model.dart';
import 'package:streamtunes/ui/band_public/view_models/donation_view_model.dart';
import 'package:streamtunes/ui/home/view_models/home_view_model.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/ui/library/view_models/playlist_detail_view_model.dart';
import 'package:streamtunes/ui/navigation/view_models/navigation_view_model.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/upload/view_models/upload_view_model.dart';

/// Raíz de composición (Composition Root).
///
/// Es el ÚNICO lugar de la app que conoce las implementaciones concretas
/// (Fake o Supabase) y que arma el grafo de objetos. Las Views solo le piden
/// ViewModels a las fábricas `create...`, nunca un repositorio.
///
///   UI (View -> ViewModel) --> data (Repository -> Service) --> domain (models)
class AppDependencies {
  AppDependencies({
    required this.authRepository,
    required this.bandsRepository,
    required this.songsRepository,
    required this.donationsRepository,
    required this.playlistsRepository,
    required this.moderationRepository,
    required this.configRepository,
    required this.paymentsRepository,
    PayoutsRepository? payoutsRepository,
    DeviceTokensRepository? deviceTokensRepository,
    PushNotificationService? pushService,
    DeviceCapabilitiesService? deviceService,
    AudioPlayerService? audioPlayerService,
    PendingFollowService? pendingFollowService,
    BackgroundUploadService? notificationService,
    DeepLinkService? deepLinkService,
    ExternalLauncherService? launcherService,
    AudioAnalyzerService? audioAnalyzer,
    this.metricsService = const BandMetricsService(),
  })  : deviceService = deviceService ?? DeviceCapabilitiesService(),
        pendingFollowService = pendingFollowService ?? PendingFollowService(),
        notificationService = notificationService ?? BackgroundUploadService(),
        deepLinkService = deepLinkService ?? DeepLinkService(),
        launcherService = launcherService ?? ExternalLauncherService(),
        audioAnalyzer = audioAnalyzer ?? AudioAnalyzerService(),
        payoutsRepository = payoutsRepository ?? FakePayoutsRepository(),
        deviceTokensRepository = deviceTokensRepository ?? FakeDeviceTokensRepository(),
        pushService = pushService ?? NoopPushNotificationService() {
    this.audioPlayerService = audioPlayerService ??
        AudioPlayerService(
          // Regla de negocio: registrar la reproducción tras 5 s de escucha.
          onPlayLogged: (songId, bandId, seconds) => songsRepository.logPlayEvent(
            songId,
            bandId,
            authRepository.currentUser?.id,
            seconds,
          ),
        );
  }

  /// Modo offline / demo / tests: repositorios en memoria.
  factory AppDependencies.fake({
    AuthRepository? authRepository,
    BandsRepository? bandsRepository,
    SongsRepository? songsRepository,
    DonationsRepository? donationsRepository,
    PlaylistsRepository? playlistsRepository,
    ModerationRepository? moderationRepository,
    ConfigRepository? configRepository,
    PayoutsRepository? payoutsRepository,
    DeviceCapabilitiesService? deviceService,
    AudioPlayerService? audioPlayerService,
    PendingFollowService? pendingFollowService,
    DeepLinkService? deepLinkService,
  }) {
    return AppDependencies(
      authRepository: authRepository ?? FakeAuthRepository(),
      bandsRepository: bandsRepository ?? FakeBandsRepository(),
      songsRepository: songsRepository ?? FakeSongsRepository(),
      donationsRepository: donationsRepository ?? FakeDonationsRepository(),
      playlistsRepository: playlistsRepository ?? FakePlaylistsRepository(),
      moderationRepository: moderationRepository ?? FakeModerationRepository(),
      configRepository: configRepository ?? FakeConfigRepository(),
      paymentsRepository: FakePaymentsRepository(),
      payoutsRepository: payoutsRepository,
      deviceService: deviceService,
      audioPlayerService: audioPlayerService,
      pendingFollowService: pendingFollowService,
      deepLinkService: deepLinkService,
    );
  }

  /// Producción: repositorios conectados a Supabase.
  factory AppDependencies.supabase(SupabaseClient client) {
    final notifications = BackgroundUploadService();
    return AppDependencies(
      authRepository: SupabaseAuthRepository(client),
      bandsRepository: SupabaseBandsRepository(client),
      songsRepository: SupabaseSongsRepository(client),
      donationsRepository: SupabaseDonationsRepository(client),
      playlistsRepository: SupabasePlaylistsRepository(client),
      moderationRepository: SupabaseModerationRepository(client),
      configRepository: SupabaseConfigRepository(client),
      paymentsRepository: SupabasePaymentsRepository(client),
      payoutsRepository: SupabasePayoutsRepository(client),
      deviceTokensRepository: SupabaseDeviceTokensRepository(client),
      pushService: FirebasePushNotificationService(localNotifications: notifications),
      notificationService: notifications,
    );
  }

  // ---- Capa de datos: repositorios ----
  final AuthRepository authRepository;
  final BandsRepository bandsRepository;
  final SongsRepository songsRepository;
  final DonationsRepository donationsRepository;
  final PlaylistsRepository playlistsRepository;
  final ModerationRepository moderationRepository;
  final ConfigRepository configRepository;
  final PaymentsRepository paymentsRepository;
  final PayoutsRepository payoutsRepository;
  final DeviceTokensRepository deviceTokensRepository;

  // ---- Capa de datos: servicios ----
  final DeviceCapabilitiesService deviceService;
  late final AudioPlayerService audioPlayerService;
  final PendingFollowService pendingFollowService;
  final BackgroundUploadService notificationService;
  final DeepLinkService deepLinkService;
  final ExternalLauncherService launcherService;
  final AudioAnalyzerService audioAnalyzer;
  final BandMetricsService metricsService;
  final PushNotificationService pushService;

  // ---- Fábricas de ViewModels ----

  SessionViewModel createSessionViewModel() => SessionViewModel(
        authRepo: authRepository,
        bandsRepo: bandsRepository,
        configRepo: configRepository,
        pendingFollowService: pendingFollowService,
        push: pushService,
        deviceTokens: deviceTokensRepository,
      );

  PlayerViewModel createPlayerViewModel() => PlayerViewModel(playerService: audioPlayerService);

  LibraryViewModel createLibraryViewModel() =>
      LibraryViewModel(playlistsRepo: playlistsRepository, bandsRepo: bandsRepository);

  NavigationViewModel createNavigationViewModel(SessionViewModel session) =>
      NavigationViewModel(
        bandsRepo: bandsRepository,
        deepLinks: deepLinkService,
        session: session,
        push: pushService,
      );

  HomeViewModel createHomeViewModel() => HomeViewModel(
        songsRepo: songsRepository,
        bandsRepo: bandsRepository,
        authRepo: authRepository,
        pendingFollowService: pendingFollowService,
        deviceService: deviceService,
      );

  BandPublicViewModel createBandPublicViewModel(String bandId) => BandPublicViewModel(
        bandsRepo: bandsRepository,
        songsRepo: songsRepository,
        donationsRepo: donationsRepository,
        launcher: launcherService,
        bandId: bandId,
      );

  DonationViewModel createDonationViewModel({
    required Band band,
    AppUser? currentUser,
    double maxAmount = 5000,
  }) =>
      DonationViewModel(
        band: band,
        currentUser: currentUser,
        maxAmount: maxAmount,
        paymentsRepo: paymentsRepository,
        launcher: launcherService,
      );

  BandDashboardViewModel createBandDashboardViewModel(String bandId) => BandDashboardViewModel(
        bandsRepo: bandsRepository,
        songsRepo: songsRepository,
        payoutsRepo: payoutsRepository,
        donationsRepo: donationsRepository,
        deviceService: deviceService,
        metricsService: metricsService,
        bandId: bandId,
      );

  BandRegistrationViewModel createBandRegistrationViewModel(SessionViewModel session) =>
      BandRegistrationViewModel(bandsRepo: bandsRepository, session: session, deviceService: deviceService);

  UploadViewModel createUploadViewModel() => UploadViewModel(
        songsRepo: songsRepository,
        configRepo: configRepository,
        deviceService: deviceService,
        audioAnalyzer: audioAnalyzer,
        notifications: notificationService,
      );

  AdminModerationViewModel createAdminModerationViewModel() => AdminModerationViewModel(
        moderationRepo: moderationRepository,
        payoutsRepo: payoutsRepository,
        donationsRepo: donationsRepository,
        configRepo: configRepository,
      );

  PlaylistDetailViewModel createPlaylistDetailViewModel(
    Playlist playlist,
    LibraryViewModel library,
  ) =>
      PlaylistDetailViewModel(playlist: playlist, library: library, songsRepo: songsRepository);

  /// Libera todos los recursos (streams, canales realtime, reproductor).
  /// Lo llama la raíz de la app en su `dispose`.
  void dispose() {
    audioAnalyzer.dispose(); // mata el isolate worker
    pushService.dispose();
    notificationService.dispose();
    audioPlayerService.dispose();
    authRepository.dispose();
    donationsRepository.dispose();
  }
}
