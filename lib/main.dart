import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/config/dependencies.dart';
import 'package:streamtunes/config/environment.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/ui/navigation/views/navigation_shell.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';
import 'package:streamtunes/ui/session/view_models/session_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Reproducción con pantalla bloqueada (solo móvil).
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

  // 2. Modo dual: Supabase si hay credenciales y conexión; si no, repositorios Fake.
  final dependencies = await _buildDependencies();

  // 3. Servicios de plataforma que necesitan inicializarse antes de la UI.
  await dependencies.notificationService.initialize();

  runApp(StreamTunesApp(dependencies: dependencies));

  // 4. Push (Firebase): DESPUÉS de runApp, porque pedir el permiso muestra un
  //    diálogo y no queremos bloquear el primer frame esperando la respuesta.
  unawaited(dependencies.pushService.initialize());
}

Future<AppDependencies> _buildDependencies() async {
  if (Environment.useMock || !Environment.hasSupabaseCredentials) {
    debugPrint('>>> StreamTunes en modo OFFLINE (repositorios Fake) <<<');
    return AppDependencies.fake();
  }
  try {
    await Supabase.initialize(
      url: Environment.supabaseUrl,
      publishableKey: Environment.supabaseAnonKey,
    );
    debugPrint('>>> StreamTunes conectado a Supabase Cloud <<<');
    return AppDependencies.supabase(Supabase.instance.client);
  } catch (e) {
    debugPrint('Error conectando a Supabase: $e. Usando repositorios Fake.');
    return AppDependencies.fake();
  }
}

/// Raíz de la app. Es dueña de los ViewModels GLOBALES (sesión, reproductor,
/// biblioteca): los crea en `initState` y los libera en `dispose`.
class StreamTunesApp extends StatefulWidget {
  const StreamTunesApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<StreamTunesApp> createState() => _StreamTunesAppState();
}

class _StreamTunesAppState extends State<StreamTunesApp> with WidgetsBindingObserver {
  late final SessionViewModel _sessionViewModel;
  late final PlayerViewModel _playerViewModel;
  late final LibraryViewModel _libraryViewModel;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final deps = widget.dependencies;
    _sessionViewModel = deps.createSessionViewModel()..init();
    _playerViewModel = deps.createPlayerViewModel()..init();
    _libraryViewModel = deps.createLibraryViewModel();

    // Ciclo de vida de la APP (no del widget). Reglas:
    //  * NO pausar la música al pasar a segundo plano.
    //  * Al volver (resumed): sincronizar los follows hechos sin señal.
    //  * Con presión de memoria: liberar la caché de imágenes.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        debugPrint('[Lifecycle] App reanudada: sincronizando cola offline de QR...');
        _sessionViewModel.syncPendingFollows();
      },
    );
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    debugPrint('[Memory] Presión de memoria: limpiando caché de imágenes...');
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListener.dispose();
    _sessionViewModel.dispose();
    _playerViewModel.dispose();
    _libraryViewModel.dispose();
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: widget.dependencies,
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
