import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/domain/models/playlist.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/library/view_models/playlist_detail_view_model.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/ui/library/widgets/add_songs_bottom_sheet.dart';
import 'package:streamtunes/ui/library/widgets/playlist_header.dart';
import 'package:streamtunes/ui/library/widgets/playlist_song_tile.dart';

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
    _viewModel = DependenciesScope.of(
      context,
    ).createPlaylistDetailViewModel(widget.playlist, LibraryScope.read(context))..loadSongs(forceRefresh: true);
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
    _showSnack(
      shuffle
          ? 'Reproducción aleatoria iniciada (${queue.length} temas)'
          : 'Reproduciendo "${widget.playlist.title}" en orden',
    );
  }

  void _openAddSongsModal() {
    // La carga se dispara ACÁ (handler de un tap) y no en el initState de la hoja:
    // notificar listeners durante la fase de build lanza "setState() called during build".
    _viewModel.prepareAddSongs();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => AddSongsBottomSheet(viewModel: _viewModel),
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
      messenger.showSnackBar(SnackBar(content: Text('Playlist "${widget.playlist.title}" eliminada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _viewModel, builder: (context, _) => _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
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
            PlaylistHeader(
              title: widget.playlist.title,
              songCount: songCount,
              canPlay: !vm.isEmpty,
              onPlay: (shuffle) => _play(shuffle: shuffle),
              onAddSongs: _openAddSongsModal,
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
                child: ErrorBanner(
                  title: 'No se pudieron cargar los temas de la playlist',
                  message: vm.errorMessage!,
                  onRetry: () => vm.loadSongs(forceRefresh: true),
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
              for (final (index, song) in vm.songs.indexed)
                PlaylistSongTile(index: index, song: song, queue: vm.songs, onRemove: _removeSong),
            const SizedBox(height: 90), // Espacio para barra de reproducción flotante
          ],
        ),
      ),
    );
  }
}
