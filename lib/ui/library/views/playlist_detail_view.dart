import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/library/view_models/playlist_detail_view_model.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';

class PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailView({super.key, required this.playlist});

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  late final PlaylistDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createPlaylistDetailViewModel(
      widget.playlist,
      LibraryScope.read(context),
    )..loadSongs(forceRefresh: true);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _play({required bool shuffle}) {
    final queue = _viewModel.queueFor(shuffle: shuffle);
    if (queue == null) {
      _showSnack('No hay temas en la playlist para reproducir.');
      return;
    }
    PlayerScope.read(context).playSong(queue.first, queue: queue);
    _showSnack(shuffle
        ? 'Reproducción aleatoria iniciada (${queue.length} temas)'
        : 'Reproduciendo "${widget.playlist.title}" en orden');
  }

  void _openAddSongsModal() {
    // La carga se dispara ACÁ (handler de un tap) y no en el initState de la hoja:
    // notificar listeners durante la fase de build lanza "setState() called during build".
    _viewModel.prepareAddSongs();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSongsBottomSheet(viewModel: _viewModel),
    );
  }

  Future<bool> _confirm({required String title, required String body, required String action}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _removeSong(Song song) async {
    final ok = await _confirm(
      title: 'Quitar canción',
      body: '¿Deseas quitar "${song.title}" de "${widget.playlist.title}"?',
      action: 'Quitar',
    );
    if (!ok || !mounted) return;
    if (await _viewModel.removeSong(song) && mounted) {
      _showSnack('"${song.title}" quitada de la playlist.');
    }
  }

  Future<void> _deletePlaylist() async {
    final ok = await _confirm(
      title: 'Eliminar Playlist',
      body: '¿Estás seguro de que deseas eliminar permanentemente la playlist "${widget.playlist.title}"?',
      action: 'Eliminar',
    );
    if (!ok || !mounted) return;
    // Se capturan ANTES del await/pop: después de pop() este context queda desmontado.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (await _viewModel.deletePlaylist() && mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Playlist "${widget.playlist.title}" eliminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _viewModel, builder: (context, _) => _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final vm = _viewModel;
    final songCount = vm.songCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, color: AppTheme.primary),
            tooltip: 'Añadir canciones',
            onPressed: _openAddSongsModal,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'delete') {
                _deletePlaylist();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar Playlist', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.loadSongs(forceRefresh: true),
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Cabecera decorativa de Playlist
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.25),
                    AppTheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.playlist_play, color: AppTheme.primary, size: 44),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.playlist.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$songCount canciones guardadas • Tu Playlist',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  // Botones de Reproducción
                  Row(
                    children: [
                      // Botón Reproducir en Orden
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: vm.isEmpty ? null : () => _play(shuffle: false),
                          icon: const Icon(Icons.play_arrow, size: 22),
                          label: const Text('En orden', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón Aleatorio
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: vm.isEmpty ? null : () => _play(shuffle: true),
                          icon: const Icon(Icons.shuffle, size: 20, color: AppTheme.primary),
                          label: const Text('Aleatorio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botón "+ Añadir canciones a la playlist"
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _openAddSongsModal,
                      icon: const Icon(Icons.add, size: 20, color: AppTheme.primary),
                      label: const Text(
                        'Añadir más canciones',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Encabezado de la lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CANCIONES',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openAddSongsModal,
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: const Text(
                    'Añadir',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Estado de Carga / Error / Lista
            if (vm.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (vm.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Text(vm.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => vm.loadSongs(forceRefresh: true),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (vm.isEmpty)
              EmptyStateView(
                icon: Icons.music_off,
                title: 'Tu playlist no tiene canciones aún',
                description: 'Toca el botón a continuación para explorar temas y sumarlos a tu playlist.',
                actionLabel: 'Añadir canciones',
                onAction: _openAddSongsModal,
              )
            else
              ...vm.songs.asMap().entries.map((entry) {
                final index = entry.key;
                final song = entry.value;
                final isCurrent = playerVM.currentSong?.id == song.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 46,
                            height: 46,
                            color: AppTheme.surfaceLight,
                            child: song.coverUrl != null
                                ? Image.network(
                                    song.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                      '${song.bandName ?? "Banda"} • ${song.formattedDuration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isCurrent && playerVM.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: AppTheme.primary,
                            size: 30,
                          ),
                          onPressed: () => playerVM.playOrToggle(song, queue: vm.songs),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                          onSelected: (val) {
                            if (val == 'remove') {
                              _removeSong(song);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_remove, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Quitar de la playlist', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => playerVM.playOrToggle(song, queue: vm.songs),
                  ),
                );
              }),
            const SizedBox(height: 90), // Espacio para barra de reproducción flotante
          ],
        ),
      ),
    );
  }
}

/// Modal inferior para buscar y sumar canciones a la playlist.
/// Comparte el [PlaylistDetailViewModel] de la pantalla (no toca repositorios).
class _AddSongsBottomSheet extends StatefulWidget {
  final PlaylistDetailViewModel viewModel;

  const _AddSongsBottomSheet({required this.viewModel});

  @override
  State<_AddSongsBottomSheet> createState() => _AddSongsBottomSheetState();
}

class _AddSongsBottomSheetState extends State<_AddSongsBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  PlaylistDetailViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addSong(Song song) async {
    final ok = await _vm.addSong(song);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${song.title}" sumada a "${_vm.playlist.title}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _vm, builder: (context, _) => _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          // Tirador superior del modal
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título y botón cerrar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Añadir temas a playlist',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sumar canciones a "${_vm.playlist.title}"',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buscador de canciones
          TextField(
            controller: _searchController,
            onChanged: _vm.filterAvailable,
            decoration: InputDecoration(
              hintText: 'Buscar por título, banda o género...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _vm.filterAvailable('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de canciones para sumar
          Expanded(
            child: _buildSongList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    if (_vm.isLoadingAvailable) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_vm.availableError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_vm.availableError!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _vm.loadAvailableSongs,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final filtered = _vm.filteredAvailableSongs;
    final addedIds = _vm.songIds;
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron canciones disponibles.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(color: AppTheme.surfaceLight, height: 1),
      itemBuilder: (context, idx) {
        final song = filtered[idx];
        final isAdded = addedIds.contains(song.id);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 44,
              height: 44,
              color: AppTheme.surfaceLight,
              child: song.coverUrl != null
                  ? Image.network(
                      song.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: AppTheme.textSecondary),
                    )
                  : const Icon(Icons.music_note, color: AppTheme.textSecondary),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '${song.bandName ?? "Banda"} • ${song.formattedDuration}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: isAdded
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: AppTheme.primary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Añadida',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => _addSong(song),
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: const Text('Sumar', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
        );
      },
    );
  }
}
