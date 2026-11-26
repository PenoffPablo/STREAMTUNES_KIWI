import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/account/widgets/account_view.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/band_dashboard_view.dart';
import 'package:streamtunes/ui/band_public/widgets/band_public_view.dart';
import 'package:streamtunes/ui/home/widgets/home_view.dart';
import 'package:streamtunes/ui/library/widgets/library_view.dart';
import 'package:streamtunes/ui/upload/widgets/upload_view.dart';
import 'package:streamtunes/ui/player/widgets/player_bar.dart';
import 'package:streamtunes/ui/core/widgets/spend_cap_banner.dart';
import 'package:streamtunes/ui/navigation/view_models/navigation_view_model.dart';

class _NavDestinationItem {
  final Widget widget;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavDestinationItem({
    required this.widget,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  late final NavigationViewModel _viewModel;
  StreamSubscription<Band>? _openBandSub;
  StreamSubscription<String>? _playerErrorSub;
  StreamSubscription<void>? _sessionExpiredSub;

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context)
        .createNavigationViewModel(SessionScope.read(context))
      ..init();
    // La View solo reacciona al stream: la resolución del link vive en el ViewModel.
    _openBandSub = _viewModel.openBandRequests.listen(_openBand);
    // El reproductor es global: sus errores se muestran desde acá, que está
    // montado mientras la app está abierta.
    _playerErrorSub = PlayerScope.read(context).errors.listen(_showPlayerError);
    _sessionExpiredSub = SessionScope.read(context).sessionExpired.listen((_) => _goToLogin());
  }

  /// La sesión venció: se cierran las pantallas abiertas (panel de admin,
  /// perfil de banda...) y se abre "Cuenta", donde está el inicio de sesión.
  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Sin sesión quedan las pestañas de visitante: Inicio y Cuenta.
    _viewModel.selectTab(1, tabCount: 2);
    showErrorSnackBar(context, title: 'Sesión vencida', message: SessionViewModel.sessionExpiredMessage);
  }

  void _showPlayerError(String message) {
    if (!mounted) return;
    showErrorSnackBar(context, title: 'Problema con la reproducción', message: message);
  }

  void _openBand(Band band) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BandPublicView(bandId: band.id)),
    );
  }

  @override
  void dispose() {
    _openBandSub?.cancel();
    _playerErrorSub?.cancel();
    _sessionExpiredSub?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  List<_NavDestinationItem> _getDestinations(bool isAuthenticated, bool isMusician) {
    if (!isAuthenticated) {
      // 1. Visitante
      return const [
        _NavDestinationItem(
          widget: HomeView(),
          label: 'Inicio',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _NavDestinationItem(
          widget: AccountView(),
          label: 'Cuenta',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
        ),
      ];
    } else if (!isMusician) {
      // 2. Oyente
      return const [
        _NavDestinationItem(
          widget: HomeView(),
          label: 'Inicio',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _NavDestinationItem(
          widget: LibraryView(),
          label: 'Biblioteca',
          icon: Icons.library_music_outlined,
          selectedIcon: Icons.library_music,
        ),
        _NavDestinationItem(
          widget: AccountView(),
          label: 'Cuenta',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
        ),
      ];
    } else {
      // 3. Músico con Banda
      return const [
        _NavDestinationItem(
          widget: HomeView(),
          label: 'Inicio',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _NavDestinationItem(
          widget: UploadView(),
          label: 'Subir',
          icon: Icons.cloud_upload_outlined,
          selectedIcon: Icons.cloud_upload,
        ),
        _NavDestinationItem(
          widget: LibraryView(),
          label: 'Biblioteca',
          icon: Icons.library_music_outlined,
          selectedIcon: Icons.library_music,
        ),
        _NavDestinationItem(
          widget: BandDashboardView(),
          label: 'Mi Banda',
          icon: Icons.graphic_eq_outlined,
          selectedIcon: Icons.graphic_eq,
        ),
        _NavDestinationItem(
          widget: AccountView(),
          label: 'Cuenta',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final isAuth = sessionVM.isAuthenticated && !sessionVM.isAnonymous;
    final isMusician = sessionVM.isMusician;
    final isSpendCapActive = sessionVM.config.spendCapActive;

    final destinations = _getDestinations(isAuth, isMusician);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        // No se modifica estado dentro de build: el VM calcula el índice válido.
        final currentIndex = _viewModel.indexFor(destinations.length);
        void onSelect(int idx) => _viewModel.selectTab(idx, tabCount: destinations.length);
        return _buildLayout(destinations, currentIndex, onSelect, isSpendCapActive);
      },
    );
  }

  Widget _buildLayout(
    List<_NavDestinationItem> destinations,
    int currentIndex,
    ValueChanged<int> onSelect,
    bool isSpendCapActive,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        return Scaffold(
          body: Column(
            children: [
              // Aviso de límite de gasto y saturación de presupuesto
              if (isSpendCapActive) const SpendCapBanner(),

              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          NavigationRail(
                            selectedIndex: currentIndex,
                            onDestinationSelected: onSelect,
                            labelType: NavigationRailLabelType.all,
                            destinations: destinations.map((d) {
                              return NavigationRailDestination(
                                icon: Icon(d.icon),
                                selectedIcon: Icon(d.selectedIcon),
                                label: Text(d.label),
                              );
                            }).toList(),
                          ),
                          const VerticalDivider(thickness: 1, width: 1, color: AppTheme.surfaceLight),
                          Expanded(
                            child: Stack(
                              children: [
                                destinations[currentIndex].widget,
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: PlayerBar(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          destinations[currentIndex].widget,
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: PlayerBar(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onSelect,
                  destinations: destinations.map((d) {
                    return NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

