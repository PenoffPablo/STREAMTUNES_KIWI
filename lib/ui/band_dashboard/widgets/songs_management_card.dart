import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Catálogo de la banda (cupo de 20 temas) con editar y eliminar por tema.
class SongsManagementCard extends StatelessWidget {
  const SongsManagementCard({super.key, required this.songs, required this.onEdit, required this.onDelete});

  final List<Song> songs;
  final ValueChanged<Song> onEdit;
  final ValueChanged<Song> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MIS CANCIONES SUBIDAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '${songs.length}/20 Temas',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Administra tu catálogo: edita el título, género o letra sincronizada (LRC), o elimina una canción si la subiste por error para liberar tu cupo.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (songs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Aún no has subido canciones con esta banda.\nUsa la pestaña "Subir" del menú inferior para publicar tu música.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...songs.map((song) {
              final minutes = song.durationSeconds ~/ 60;
              final seconds = (song.durationSeconds % 60).toString().padLeft(2, '0');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: AppTheme.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: Colors.black26,
                      child: song.coverUrl != null
                          ? Image.network(
                              song.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: AppTheme.primary),
                            )
                          : const Icon(Icons.music_note, color: AppTheme.primary),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${song.genre} • $minutes:$seconds • ${song.playCount} plays',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                    onSelected: (val) {
                      if (val == 'edit') {
                        onEdit(song);
                      } else if (val == 'delete') {
                        onDelete(song);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: AppTheme.primary),
                            SizedBox(width: 10),
                            Text('Editar metadatos'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Eliminar canción', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
