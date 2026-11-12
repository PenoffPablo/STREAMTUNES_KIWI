import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/views/account_view.dart';
import 'package:streamtunes/views/band_dashboard_view.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/views/home_view.dart';
import 'package:streamtunes/views/library_view.dart';
import 'package:streamtunes/views/upload_view.dart';
import 'package:streamtunes/widgets/player_bar.dart';
import 'package:streamtunes/widgets/spend_cap_banner.dart';

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
  int _currentIndex = 0;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    try {
      _appLinks = AppLinks();
      _linkSubscription = _appLinks!.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('[DeepLink] No soportado en este entorno: $e');
    }
  }

  void _handleDeepLink(Uri uri) async {
    final path = uri.path;
    if (path.contains('/band/')) {
      final slug = path.split('/band/').last.split('?').first;
      if (slug.isNotEmpty && mounted) {
        final repos = RepositoriesScope.of(context);
        Band? band = await repos.bandsRepository.getBandBySlug(slug);
        band ??= await repos.bandsRepository.getBandById(slug);

        if (band != null && mounted) {
          final sessionVM = SessionScope.of(context);
          if (sessionVM.currentUser != null) {
            await repos.bandsRepository.followBand(band.id, sessionVM.currentUser!.id);
          }
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => BandPublicView(bandId: band!.id)),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

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
                            selectedIndex: _currentIndex,
                            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
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
                                destinations[_currentIndex].widget,
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
                          destinations[_currentIndex].widget,
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
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
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

