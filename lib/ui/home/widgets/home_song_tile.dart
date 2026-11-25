import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/library/widgets/add_to_playlist_dialog.dart';

/// Tema del feed: reproducir/pausar y "Sumar a playlist".
class HomeSongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;

  const HomeSongTile({super.key, required this.song, required this.allSongs});

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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_note, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                ),
              ),
              if (isCurrent)
                Container(
                  width: 48,
                  height: 48,
                  color: Colors.black45,
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
                onPressed: () => playerVM.playOrToggle(song, queue: allSongs),
              ),
            ],
          ),
          onTap: () => playerVM.playOrToggle(song, queue: allSongs),
        ),
      ),
    );
  }
}
