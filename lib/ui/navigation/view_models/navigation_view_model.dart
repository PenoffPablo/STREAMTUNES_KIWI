import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/services/device/deep_link_service.dart';
import 'package:streamtunes/data/services/notifications/push_notification_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/ui/session/view_models/session_view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// ViewModel del shell de navegación.
///
/// * Guarda la pestaña seleccionada.
/// * Convierte los deep links en "pedidos de navegación" a perfiles de banda
///   ([openBandRequests]) que la View escucha para hacer `Navigator.push`.
class NavigationViewModel extends ViewModel {
  NavigationViewModel({
    required this.bandsRepo,
    required this.deepLinks,
    required this.session,
    this.push,
  });

  final BandsRepository bandsRepo;
  final DeepLinkService deepLinks;
  final SessionViewModel session;
  final PushNotificationService? push;

  int _currentIndex = 0;
  StreamSubscription<Band>? _linkSub;
  StreamSubscription<String>? _pushSub;
  final _openBandController = StreamController<Band>.broadcast();

  int get currentIndex => _currentIndex;

  /// Bandas a abrir (vienen de deep links o de notificaciones push).
  Stream<Band> get openBandRequests => _openBandController.stream;

  void init() {
    // slug -> (asyncMap) Band? -> where != null. asyncMap procesa los links en
    // orden y de a uno, sin lanzar búsquedas superpuestas.
    _linkSub ??= deepLinks.bandLinks
        .asyncMap(_resolveAndFollow)
        .where((band) => band != null)
        .cast<Band>()
        .listen(_openBandController.add,
            onError: (Object e) => debugPrint('[NavigationViewModel] Deep link: $e'));

    // Tocar una notificación push abre el perfil de la banda que la generó.
    _pushSub ??= push?.openedMessages
        .map((m) => m.bandId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .listen(openBand);
  }

  void selectTab(int index, {required int tabCount}) {
    final clamped = index.clamp(0, tabCount - 1);
    if (clamped == _currentIndex) return;
    _currentIndex = clamped;
    notifyListeners();
  }

  /// Ajusta el índice si cambió la cantidad de pestañas (por ejemplo al cerrar sesión).
  int indexFor(int tabCount) => _currentIndex >= tabCount ? 0 : _currentIndex;

  /// Abre una banda por slug o ID (lo usa también el servicio de push).
  /// Abre una banda por slug o ID. Solo los links de QR (deep links) siguen a
  /// la banda; abrirla desde un push NO crea un follow.
  Future<void> openBand(String slugOrId) async {
    final band = await _resolveAndFollow(slugOrId, follow: false);
    if (band != null && !_openBandController.isClosed) _openBandController.add(band);
  }

  Future<Band?> _resolveAndFollow(String slugOrId, {bool follow = true}) async {
    try {
      final band = await bandsRepo.getBandBySlug(slugOrId).withNetworkTimeout() ??
          await bandsRepo.getBandById(slugOrId).withNetworkTimeout();
      final user = session.currentUser;
      if (follow && band != null && user != null) {
        await bandsRepo.followBand(band.id, user.id).withNetworkTimeout();
      }
      return band;
    } catch (e) {
      debugPrint('[NavigationViewModel] No se pudo resolver "$slugOrId": ${describeError(e)}');
      return null;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _pushSub?.cancel();
    _openBandController.close();
    super.dispose();
  }
}
