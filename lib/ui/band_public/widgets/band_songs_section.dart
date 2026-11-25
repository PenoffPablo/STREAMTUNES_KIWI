import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/library/widgets/add_to_playlist_dialog.dart';

/// Canciones de la banda: tocar una la reproduce con toda la lista como cola.
class BandSongsSection extends StatelessWidget {
  const BandSongsSection({super.key, required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANCIONES MÁS ESCUCHADAS',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (songs.isEmpty)
          const Text(
            'La banda no tiene canciones disponibles aún.',
            style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
          )
        else
          ...songs.map((song) => BandSongTile(song: song, allSongs: songs)),
      ],
    );
  }
}

/// Fila de una canción con reproducir/pausar y "Sumar a playlist".
class BandSongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;

  const BandSongTile({super.key, required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final isCurrent = playerVM.currentSong?.id == song.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: Icon(
            isCurrent && playerVM.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: AppTheme.primary,
            size: 30,
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, color: isCurrent ? AppTheme.primary : AppTheme.textPrimary),
          ),
          subtitle: Text(
            '${song.formattedDuration} • ${song.playCount} reproducciones',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
            tooltip: 'Sumar a Playlist',
            onPressed: () => AddToPlaylistDialog.show(context, song),
          ),
          onTap: () => playerVM.playOrToggle(song, queue: allSongs),
        ),
      ),
    );
  }
}
