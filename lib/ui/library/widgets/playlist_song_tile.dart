import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Tema de la playlist: portada o número, reproducir/pausar y "Quitar".
/// Tocarlo reproduce la playlist completa ([queue]) desde este tema.
class PlaylistSongTile extends StatelessWidget {
  const PlaylistSongTile({
    super.key,
    required this.index,
    required this.song,
    required this.queue,
    required this.onRemove,
  });

  final int index;
  final Song song;
  final List<Song> queue;
  final ValueChanged<Song> onRemove;

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final isCurrent = playerVM.currentSong?.id == song.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Icon(playerVM.isPlaying ? Icons.pause : Icons.play_arrow, color: AppTheme.primary, size: 26),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, color: isCurrent ? AppTheme.primary : AppTheme.textPrimary),
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
                isCurrent && playerVM.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppTheme.primary,
                size: 30,
              ),
              onPressed: () => playerVM.playOrToggle(song, queue: queue),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
              onSelected: (val) {
                if (val == 'remove') {
                  onRemove(song);
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
        onTap: () => playerVM.playOrToggle(song, queue: queue),
      ),
    );
  }
}
