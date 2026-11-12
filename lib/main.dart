import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/config_repository.dart';
import 'package:streamtunes/repositories/donations_repository.dart';
import 'package:streamtunes/repositories/moderation_repository.dart';
import 'package:streamtunes/repositories/playlists_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/services/audio_player_service.dart';
import 'package:streamtunes/services/background_upload_service.dart';
import 'package:streamtunes/services/device_capabilities_service.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/player_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';
import 'package:streamtunes/views/navigation_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://fajwcwabcdxetuffoiuh.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_Z-GmSTHbO64JDaBa3KXIzQ_9FuQ08rY',
);
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicialización de servicio en segundo plano y notificaciones
  await BackgroundUploadService.initialize();

  // 2. Inicialización de JustAudioBackground para reproducción con pantalla bloqueada
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.streamtunes.app.audio',
        androidNotificationChannelName: 'Reproducción StreamTunes',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('[JustAudioBackground] Advertencia inicializando fondo: $e');
    }
  }

  // 3. Inicialización en Modo Dual de Supabase
  final bool hasCredentials = kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
  bool isConnected = false;

  if (!kUseMock && hasCredentials) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        publishableKey: kSupabaseAnonKey,
      );
      isConnected = true;
      debugPrint('>>> StreamTunes conectado a Supabase Cloud <<<');
    } catch (e) {
      debugPrint('Error conectando a Supabase: $e. Activando Fake Dual-Mode.');
      isConnected = false;
    }
  } else {
    debugPrint('>>> StreamTunes ejecutando en DUAL-MODE OFFLINE (Fake Repositories) <<<');
  }

  final bool runRealSupabase = isConnected;

  // 4. Inyección de Repositorios y Servicios (Modo Dual)
  final DeviceCapabilitiesService deviceService = DeviceCapabilitiesService();
  final PendingFollowService pendingFollowService = PendingFollowService();

  late final AuthRepository authRepo;
  late final BandsRepository bandsRepo;
  late final SongsRepository songsRepo;
  late final DonationsRepository donationsRepo;
  late final PlaylistsRepository playlistsRepo;
  late final ModerationRepository moderationRepo;
  late final ConfigRepository configRepo;

  if (runRealSupabase) {
    final client = Supabase.instance.client;
    authRepo = SupabaseAuthRepository(client);
    bandsRepo = SupabaseBandsRepository(client);
    songsRepo = SupabaseSongsRepository(client);
    donationsRepo = SupabaseDonationsRepository(client);
    playlistsRepo = SupabasePlaylistsRepository(client);
    moderationRepo = SupabaseModerationRepository(client);
    configRepo = SupabaseConfigRepository(client);
  } else {
    authRepo = FakeAuthRepository();
    bandsRepo = FakeBandsRepository();
    songsRepo = FakeSongsRepository();
    donationsRepo = FakeDonationsRepository();
    playlistsRepo = FakePlaylistsRepository();
    moderationRepo = FakeModerationRepository();
    configRepo = FakeConfigRepository();
  }

  // Servicio de Reproducción de Audio
  final AudioPlayerService audioPlayerService = AudioPlayerService(
    onPlayLogged: (songId, bandId, seconds) async {
      final user = authRepo.currentUser;
      await songsRepo.logPlayEvent(songId, bandId, user?.id, seconds);
    },
  );

  runApp(
    StreamTunesApp(
      authRepository: authRepo,
      bandsRepository: bandsRepo,
      songsRepository: songsRepo,
      donationsRepository: donationsRepo,
      playlistsRepository: playlistsRepo,
      moderationRepository: moderationRepo,
      configRepository: configRepo,
      deviceService: deviceService,
      audioPlayerService: audioPlayerService,
      pendingFollowService: pendingFollowService,
    ),
  );
}

class StreamTunesApp extends StatefulWidget {
  final AuthRepository authRepository;
  final BandsRepository bandsRepository;
  final SongsRepository songsRepository;
  final DonationsRepository donationsRepository;
  final PlaylistsRepository playlistsRepository;
  final ModerationRepository moderationRepository;
  final ConfigRepository configRepository;
  final DeviceCapabilitiesService deviceService;
  final AudioPlayerService audioPlayerService;
  final PendingFollowService pendingFollowService;

  const StreamTunesApp({
    super.key,
    required this.authRepository,
    required this.bandsRepository,
    required this.songsRepository,
    required this.donationsRepository,
    required this.playlistsRepository,
    required this.moderationRepository,
    required this.configRepository,
    required this.deviceService,
    required this.audioPlayerService,
    required this.pendingFollowService,
  });

  @override
  State<StreamTunesApp> createState() => _StreamTunesAppState();
}

class _StreamTunesAppState extends State<StreamTunesApp> with WidgetsBindingObserver {
  late final SessionViewModel _sessionViewModel;
  late final PlayerViewModel _playerViewModel;
  late final LibraryViewModel _libraryViewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sessionViewModel = SessionViewModel(
      authRepo: widget.authRepository,
      bandsRepo: widget.bandsRepository,
      configRepo: widget.configRepository,
    );

    _playerViewModel = PlayerViewModel(
      playerService: widget.audioPlayerService,
    );

    _libraryViewModel = LibraryViewModel(
      playlistsRepo: widget.playlistsRepository,
      bandsRepo: widget.bandsRepository,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // REGLA ARQUITECTÓNICA:
    // NO pausar la música al pasar a paused o hidden (la música debe seguir sonando).
    if (state == AppLifecycleState.resumed) {
      debugPrint('[StreamTunes Lifecycle] App reanudada: sincronizando cola offline de QR...');
      // a) Sincronizar cola offline de sótanos
      widget.pendingFollowService.sync((bandId) async {
        final user = _sessionViewModel.currentUser;
        if (user != null) {
          return await widget.bandsRepository.followBand(bandId, user.id);
        }
        return false;
      });
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    debugPrint('[StreamTunes Memory] Presión de memoria detectada: limpiando caché de imágenes...');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionViewModel.dispose();
    _playerViewModel.dispose();
    _libraryViewModel.dispose();
    widget.audioPlayerService.dispose();
    widget.authRepository.dispose();
    widget.donationsRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoriesScope(
      authRepository: widget.authRepository,
      bandsRepository: widget.bandsRepository,
      songsRepository: widget.songsRepository,
      donationsRepository: widget.donationsRepository,
      playlistsRepository: widget.playlistsRepository,
      moderationRepository: widget.moderationRepository,
      configRepository: widget.configRepository,
      deviceService: widget.deviceService,
      audioPlayerService: widget.audioPlayerService,
      pendingFollowService: widget.pendingFollowService,
      child: SessionScope(
        viewModel: _sessionViewModel,
        child: PlayerScope(
          viewModel: _playerViewModel,
          child: LibraryScope(
            viewModel: _libraryViewModel,
            child: MaterialApp(
              title: 'StreamTunes',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: const NavigationShell(),
            ),
          ),
        ),
      ),
    );
  }
}
