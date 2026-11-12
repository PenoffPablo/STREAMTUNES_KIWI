import 'package:flutter/material.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/widgets/now_playing_modal.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final song = playerVM.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final progressFraction = playerVM.duration.inMilliseconds > 0
        ? (playerVM.position.inMilliseconds / playerVM.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => NowPlayingModal.show(context),
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Barra de progreso fina en la parte superior
            LinearProgressIndicator(
              value: progressFraction,
              minHeight: 2,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // Mini Portada
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.surfaceLight,
                        child: song.coverUrl != null
                            ? Image.network(
                                song.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.music_note,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Título y Banda
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.bandName ?? 'Banda Independiente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botón Play / Pause
                    IconButton(
                      icon: Icon(
                        playerVM.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppTheme.textPrimary,
                        size: 28,
                      ),
                      onPressed: () => playerVM.togglePlayPause(),
                    ),

                    // Botón Siguiente
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next,
                        color: AppTheme.textSecondary,
                        size: 26,
                      ),
                      onPressed: () => playerVM.skipToNext(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
