import 'package:flutter/material.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/home_view_model.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/widgets/add_to_playlist_dialog.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';
import 'package:streamtunes/widgets/qr_scanner_dialog.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  HomeViewModel? _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel == null) {
      final repos = RepositoriesScope.of(context);
      _viewModel = HomeViewModel(
        songsRepo: repos.songsRepository,
        bandsRepo: repos.bandsRepository,
        authRepo: repos.authRepository,
        pendingFollowService: repos.pendingFollowService,
      );
      _viewModel!.loadFeed();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  void _scanLiveQr() async {
    final rawCode = await QrScannerDialog.show(context);
    if (rawCode != null && mounted) {
      final result = await _viewModel!.handleQrScan(rawCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: result.isOffline ? AppTheme.accentOrange : AppTheme.primary,
            content: Text(
              result.message,
              style: TextStyle(
                color: result.isOffline ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        if (result.band != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BandPublicView(bandId: result.band!.id),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return ListenableBuilder(
      listenable: _viewModel!,
      builder: (context, _) {
        final vm = _viewModel!;
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: AppTheme.primary, size: 24),
                SizedBox(width: 8),
                Text('StreamTunes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                              vm.search('');
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
                        return _BandCard(band: band);
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
                else if (vm.latestSongs.isEmpty)
                  EmptyStateView(
                    icon: Icons.music_off,
                    title: 'No hay música con estos filtros',
                    description: 'Prueba buscando otro término o seleccionando "Todos" los géneros.',
                    actionLabel: 'Restablecer filtros',
                    onAction: () {
                      _searchController.clear();
                      vm.setGenre('Todos');
                    },
                  )
                else
                  ...vm.latestSongs.map((song) => _SongTile(
                        song: song,
                        allSongs: vm.latestSongs,
                      )),
                const SizedBox(height: 80), // Margen inferior para la barra de reproducción continua
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BandCard extends StatelessWidget {
  final Band band;
  const _BandCard({required this.band});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => BandPublicView(bandId: band.id)),
        );
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: AppTheme.surfaceLight,
                child: band.coverUrl != null
                    ? Image.network(
                        band.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.groups, color: AppTheme.textSecondary),
                      )
                    : const Icon(Icons.groups, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    band.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    band.genre,
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${band.followerCount} seguidores',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;

  const _SongTile({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final isCurrent = playerVM.currentSong?.id == song.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 48,
                  height: 48,
                  color: AppTheme.surfaceLight,
                  child: song.coverUrl != null
                      ? Image.network(
                          song.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                ),
              ),
              if (isCurrent)
                Container(
                  width: 48,
                  height: 48,
                  color: Colors.black45,
                  child: Icon(
                    playerVM.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '${song.bandName ?? "Banda Independiente"} • ${song.formattedDuration}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
                tooltip: 'Sumar a Playlist',
                onPressed: () => AddToPlaylistDialog.show(context, song),
              ),
              IconButton(
                icon: Icon(
                  isCurrent && playerVM.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: AppTheme.primary,
                  size: 32,
                ),
                onPressed: () {
                  if (isCurrent) {
                    playerVM.togglePlayPause();
                  } else {
                    playerVM.playSong(song, queue: allSongs);
                  }
                },
              ),
            ],
          ),
          onTap: () {
            if (isCurrent) {
              playerVM.togglePlayPause();
            } else {
              playerVM.playSong(song, queue: allSongs);
            }
          },
        ),
      ),
    );
  }
}
