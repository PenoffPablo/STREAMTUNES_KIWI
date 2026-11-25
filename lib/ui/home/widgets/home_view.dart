import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/home/view_models/home_view_model.dart';
import 'package:streamtunes/ui/band_public/widgets/band_public_view.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/ui/core/widgets/qr_scanner_dialog.dart';
import 'package:streamtunes/ui/home/widgets/home_band_card.dart';
import 'package:streamtunes/ui/home/widgets/home_song_tile.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // El ViewModel se crea UNA vez en initState (no en didChangeDependencies,
  // que puede ejecutarse muchas veces) y se libera en dispose.
  late final HomeViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createHomeViewModel()..init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _scanLiveQr() async {
    final rawCode = await QrScannerDialog.show(context, hasCamera: _viewModel.hasCamera);
    if (rawCode != null && mounted) {
      final result = await _viewModel.handleQrScan(rawCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: result.isOffline ? AppTheme.accentOrange : AppTheme.primary,
            content: Text(
              result.message,
              style: TextStyle(color: result.isOffline ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        if (result.band != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => BandPublicView(bandId: result.band!.id)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final vm = _viewModel;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/images/logo.png', height: 28, width: 28, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                const Text('StreamTunes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _scanLiveQr,
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear QR en Vivo',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => vm.loadFeed(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Buscador en tiempo real
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar canciones, bandas o géneros...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              vm.clearSearch();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => vm.search(val),
                ),
                const SizedBox(height: 14),

                // Botones de selección para filtrar por género
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: HomeViewModel.availableGenres.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final genre = HomeViewModel.availableGenres[idx];
                      final isSelected = vm.selectedGenre == genre;
                      return ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.surfaceLight,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (_) => vm.setGenre(genre),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Sección: Bandas Destacadas del Colectivo
                if (vm.approvedBands.isNotEmpty) ...[
                  const Text(
                    'BANDAS INDEPENDIENTES',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: vm.approvedBands.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final band = vm.approvedBands[idx];
                        return HomeBandCard(band: band);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Sección: Últimos Lanzamientos Cronológicos (Sin algoritmos opacos)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ÚLTIMOS LANZAMIENTOS CRONOLÓGICOS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${vm.latestSongs.length} temas',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (vm.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  )
                else if (vm.errorMessage != null && vm.latestSongs.isEmpty)
                  EmptyStateView(
                    icon: Icons.wifi_off,
                    title: 'No pudimos cargar la música',
                    description: vm.errorMessage!,
                    actionLabel: 'Reintentar',
                    onAction: vm.loadFeed,
                  )
                else if (vm.latestSongs.isEmpty)
                  EmptyStateView(
                    icon: Icons.music_off,
                    title: 'No hay música con estos filtros',
                    description: 'Prueba buscando otro término o seleccionando "Todos" los géneros.',
                    actionLabel: 'Restablecer filtros',
                    onAction: () {
                      _searchController.clear();
                      vm.resetFilters();
                    },
                  )
                else
                  ...vm.latestSongs.map((song) => HomeSongTile(song: song, allSongs: vm.latestSongs)),
                const SizedBox(height: 80), // Margen inferior para la barra de reproducción continua
              ],
            ),
          ),
        );
      },
    );
  }
}
