import 'package:flutter/material.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/widgets/add_to_playlist_dialog.dart';
import 'package:streamtunes/widgets/waveform_painter.dart';

class NowPlayingModal extends StatefulWidget {
  const NowPlayingModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NowPlayingModal(),
    );
  }

  @override
  State<NowPlayingModal> createState() => _NowPlayingModalState();
}

class _NowPlayingModalState extends State<NowPlayingModal> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastAutoScrolledIndex = -1;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLyric(int index) {
    if (index == _lastAutoScrolledIndex || !_lyricsScrollController.hasClients) return;
    _lastAutoScrolledIndex = index;

    final targetOffset = (index * 42.0).clamp(
      0.0,
      _lyricsScrollController.position.maxScrollExtent,
    );

    _lyricsScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final song = playerVM.currentSong;

    if (song == null) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: Text('No hay ninguna canción reproduciéndose')),
      );
    }

    if (playerVM.currentLyricIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLyric(playerVM.currentLyricIndex);
      });
    }

    final progressFraction = playerVM.duration.inMilliseconds > 0
        ? (playerVM.position.inMilliseconds / playerVM.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado con botón de cerrar y sumar a lista de reproducción
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  song.genre.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add, color: AppTheme.textPrimary),
                  tooltip: 'Sumar a Playlist',
                  onPressed: () => AddToPlaylistDialog.show(context, song),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // Portada Grande
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 260,
                      height: 260,
                      color: AppTheme.surfaceLight,
                      child: song.coverUrl != null
                          ? Image.network(
                              song.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.music_note,
                                size: 80,
                                color: AppTheme.textSecondary,
                              ),
                            )
                          : const Icon(Icons.music_note, size: 80, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título y Banda
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.bandName ?? 'Banda Independiente',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visualizador interactivo de forma de onda
                  if (song.waveformPeaks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 38,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: WaveformPainter(
                            peaks: song.waveformPeaks,
                            progress: progressFraction,
                          ),
                        ),
                      ),
                    ),

                  // Barra de progreso y tiempos
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: AppTheme.surfaceLight,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: playerVM.position.inSeconds.toDouble().clamp(
                            0.0,
                            playerVM.duration.inSeconds.toDouble() > 0
                                ? playerVM.duration.inSeconds.toDouble()
                                : 1.0,
                          ),
                      max: playerVM.duration.inSeconds.toDouble() > 0
                          ? playerVM.duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (val) {
                        playerVM.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(playerVM.position),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Text(
                          _formatDuration(playerVM.duration),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Controles de Reproducción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () => playerVM.skipToPrevious(),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 42,
                          color: Colors.black,
                          icon: Icon(
                            playerVM.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: () => playerVM.togglePlayPause(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_next),
                        onPressed: () => playerVM.skipToNext(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sección: Letra Sincronizada (Karaoke LRC)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.mic, color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'LETRA SINCRONIZADA (KARAOKE LRC)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (playerVM.lyrics.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Esta canción no tiene letra sincronizada cargada.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 180,
                            child: ListView.builder(
                              controller: _lyricsScrollController,
                              itemCount: playerVM.lyrics.length,
                              itemBuilder: (context, idx) {
                                final line = playerVM.lyrics[idx];
                                final isActive = idx == playerVM.currentLyricIndex;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isActive ? 17 : 14,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
