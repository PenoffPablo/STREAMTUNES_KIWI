import 'package:flutter/material.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';

class AddToPlaylistDialog extends StatefulWidget {
  final Song song;

  const AddToPlaylistDialog({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showDialog(
      context: context,
      builder: (ctx) => AddToPlaylistDialog(song: song),
    );
  }

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final _newPlaylistController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _newPlaylistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final libraryVM = LibraryScope.of(context);
    final user = sessionVM.currentUser;

    if (user == null || user.isAnonymous) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Inicia sesión'),
        content: const Text(
          'Para crear playlists y guardar tus temas favoritos necesitas una cuenta en StreamTunes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    final playlists = libraryVM.playlists;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Sumar "${widget.song.title}"'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona una de tus playlists:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No tienes playlists creadas todavía.',
                    style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...playlists.map((pl) {
                  final isAlreadyIn = pl.songIds.contains(widget.song.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.playlist_play, color: AppTheme.primary),
                    title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${pl.songIds.length} canciones'),
                    trailing: isAlreadyIn
                        ? const Icon(Icons.check, color: AppTheme.primary)
                        : null,
                    onTap: isAlreadyIn
                        ? null
                        : () async {
                            final success = await libraryVM.addSongToPlaylist(pl.id, widget.song.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Agregada a "${pl.title}"'
                                        : 'No se pudo agregar a la playlist',
                                  ),
                                ),
                              );
                            }
                          },
                  );
                }),
              const Divider(height: 24, color: AppTheme.surfaceLight),
              if (!_isCreating)
                TextButton.icon(
                  onPressed: () => setState(() => _isCreating = true),
                  icon: const Icon(Icons.add, color: AppTheme.primary),
                  label: const Text('Nueva Playlist', style: TextStyle(color: AppTheme.primary)),
                )
              else ...[
                TextField(
                  controller: _newPlaylistController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la playlist',
                    hintText: 'Ej. Fuzz del Conurbano',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isCreating = false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final title = _newPlaylistController.text.trim();
                        if (title.isNotEmpty) {
                          final pl = await libraryVM.createPlaylist(user.id, title);
                          if (pl != null) {
                            await libraryVM.addSongToPlaylist(pl.id, widget.song.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Playlist "$title" creada y canción sumada.')),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Crear y Guardar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

