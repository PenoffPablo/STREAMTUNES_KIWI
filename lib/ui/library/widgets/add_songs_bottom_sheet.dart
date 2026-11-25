import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/library/view_models/playlist_detail_view_model.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Modal inferior para buscar y sumar canciones a la playlist.
/// Comparte el [PlaylistDetailViewModel] de la pantalla (no toca repositorios).
class AddSongsBottomSheet extends StatefulWidget {
  final PlaylistDetailViewModel viewModel;

  const AddSongsBottomSheet({super.key, required this.viewModel});

  @override
  State<AddSongsBottomSheet> createState() => _AddSongsBottomSheetState();
}

class _AddSongsBottomSheetState extends State<AddSongsBottomSheet> {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${song.title}" sumada a "${_vm.playlist.title}"')));
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
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Título y botón cerrar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Añadir temas a playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      'Sumar canciones a "${_vm.playlist.title}"',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de canciones para sumar
          Expanded(child: _buildSongList()),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            title: 'No se pudo cargar el catálogo',
            message: _vm.availableError!,
            onRetry: _vm.loadAvailableSongs,
          ),
        ),
      );
    }

    final filtered = _vm.filteredAvailableSongs;
    final addedIds = _vm.songIds;
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No se encontraron canciones disponibles.', style: TextStyle(color: AppTheme.textSecondary)),
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
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
