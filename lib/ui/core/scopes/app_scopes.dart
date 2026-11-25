import 'package:flutter/widgets.dart';
import 'package:streamtunes/config/dependencies.dart';
import 'package:streamtunes/ui/library/view_models/library_view_model.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';

/// Expone el contenedor de dependencias (raíz de composición) al árbol.
///
/// Las Views lo usan SOLO para pedir ViewModels a sus fábricas
/// (`createHomeViewModel()`, etc.); nunca para tomar un repositorio.
class DependenciesScope extends InheritedWidget {
  const DependenciesScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  /// No registra dependencia (el contenedor no cambia), por eso es seguro
  /// llamarlo dentro de `initState`.
  static AppDependencies of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<DependenciesScope>();
    assert(scope != null, 'No se encontró DependenciesScope en el árbol de widgets.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(DependenciesScope oldWidget) => dependencies != oldWidget.dependencies;
}

/// Base para exponer un ViewModel global con dos formas de acceso:
///  * `of(context)`  -> se suscribe: el widget se reconstruye con cada cambio (usar en `build`).
///  * `read(context)`-> no se suscribe (usar en `initState`, callbacks y handlers).
T _watch<T extends Listenable, S extends InheritedNotifier<T>>(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<S>();
  assert(scope?.notifier != null, 'No se encontró $S en el árbol de widgets.');
  return scope!.notifier!;
}

T _read<T extends Listenable, S extends InheritedNotifier<T>>(BuildContext context) {
  final scope = context.getInheritedWidgetOfExactType<S>();
  assert(scope?.notifier != null, 'No se encontró $S en el árbol de widgets.');
  return scope!.notifier!;
}

/// Sesión y perfil del usuario.
class SessionScope extends InheritedNotifier<SessionViewModel> {
  const SessionScope({super.key, required SessionViewModel viewModel, required super.child})
      : super(notifier: viewModel);

  static SessionViewModel of(BuildContext context) =>
      _watch<SessionViewModel, SessionScope>(context);
  static SessionViewModel read(BuildContext context) =>
      _read<SessionViewModel, SessionScope>(context);
}

/// Reproductor continuo.
class PlayerScope extends InheritedNotifier<PlayerViewModel> {
  const PlayerScope({super.key, required PlayerViewModel viewModel, required super.child})
      : super(notifier: viewModel);

  static PlayerViewModel of(BuildContext context) =>
      _watch<PlayerViewModel, PlayerScope>(context);
  static PlayerViewModel read(BuildContext context) =>
      _read<PlayerViewModel, PlayerScope>(context);
}

/// Biblioteca personal y playlists.
class LibraryScope extends InheritedNotifier<LibraryViewModel> {
  const LibraryScope({super.key, required LibraryViewModel viewModel, required super.child})
      : super(notifier: viewModel);

  static LibraryViewModel of(BuildContext context) =>
      _watch<LibraryViewModel, LibraryScope>(context);
  static LibraryViewModel read(BuildContext context) =>
      _read<LibraryViewModel, LibraryScope>(context);
}
