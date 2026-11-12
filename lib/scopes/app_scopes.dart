import 'package:flutter/widgets.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/config_repository.dart';
import 'package:streamtunes/repositories/donations_repository.dart';
import 'package:streamtunes/repositories/moderation_repository.dart';
import 'package:streamtunes/repositories/playlists_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/services/audio_player_service.dart';
import 'package:streamtunes/services/device_capabilities_service.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/view_models/library_view_model.dart';
import 'package:streamtunes/view_models/player_view_model.dart';
import 'package:streamtunes/view_models/session_view_model.dart';

/// Contenedor raíz de repositorios y servicios sin paquetes externos
class RepositoriesScope extends InheritedWidget {
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

  const RepositoriesScope({
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
    required super.child,
  });

  static RepositoriesScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoriesScope>();
    assert(scope != null, 'No se encontró RepositoriesScope en el árbol de widgets.');
    return scope!;
  }

  @override
  bool updateShouldNotify(RepositoriesScope oldWidget) => false;
}

/// Contenedor de Ámbito de Sesión y Perfil de Usuario
class SessionScope extends InheritedNotifier<SessionViewModel> {
  const SessionScope({
    super.key,
    required SessionViewModel viewModel,
    required super.child,
  }) : super(notifier: viewModel);

  static SessionViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null && scope.notifier != null, 'No se encontró SessionScope en el árbol de widgets.');
    return scope!.notifier!;
  }
}

/// Contenedor de Ámbito del Reproductor Continuo Multimedia
class PlayerScope extends InheritedNotifier<PlayerViewModel> {
  const PlayerScope({
    super.key,
    required PlayerViewModel viewModel,
    required super.child,
  }) : super(notifier: viewModel);

  static PlayerViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlayerScope>();
    assert(scope != null && scope.notifier != null, 'No se encontró PlayerScope en el árbol de widgets.');
    return scope!.notifier!;
  }
}

/// Contenedor de Ámbito de la Biblioteca Personal y Listas de Reproducción
class LibraryScope extends InheritedNotifier<LibraryViewModel> {
  const LibraryScope({
    super.key,
    required LibraryViewModel viewModel,
    required super.child,
  }) : super(notifier: viewModel);

  static LibraryViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null && scope.notifier != null, 'No se encontró LibraryScope en el árbol de widgets.');
    return scope!.notifier!;
  }
}

