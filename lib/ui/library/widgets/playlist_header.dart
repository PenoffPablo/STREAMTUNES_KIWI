import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Cabecera de la playlist: nombre, cantidad de temas, reproducir en orden o
/// aleatorio y añadir canciones. [onPlay] recibe `true` para aleatorio.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.title,
    required this.songCount,
    required this.canPlay,
    required this.onPlay,
    required this.onAddSongs,
  });

  final String title;
  final int songCount;
  final bool canPlay;
  final ValueChanged<bool> onPlay;
  final VoidCallback onAddSongs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.25), AppTheme.surface],
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
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.playlist_play, color: AppTheme.primary, size: 44),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
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
                  onPressed: canPlay ? () => onPlay(false) : null,
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
                  onPressed: canPlay ? () => onPlay(true) : null,
                  icon: const Icon(Icons.shuffle, size: 20, color: AppTheme.primary),
                  label: const Text(
                    'Aleatorio',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
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
              onPressed: onAddSongs,
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
    );
  }
}
