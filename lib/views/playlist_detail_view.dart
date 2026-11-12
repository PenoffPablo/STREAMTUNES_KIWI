import 'package:flutter/material.dart';
import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';

class PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailView({super.key, required this.playlist});

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  List<Song>? _songs;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSongs(forceRefresh: true);
    });
  }

  Future<void> _loadSongs({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final libraryVM = LibraryScope.of(context);
      final songs = await libraryVM.getSongsForPlaylist(
        widget.playlist.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando temas de la playlist: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _playInOrder() {
    if (_songs == null || _songs!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay temas en la playlist para reproducir.')),
      );
      return;
    }
    final playerVM = PlayerScope.of(context);
    playerVM.playSong(_songs!.first, queue: _songs);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reproduciendo "${widget.playlist.title}" en orden')),
    );
  }

  void _playShuffle() {
    if (_songs == null || _songs!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay temas en la playlist para reproducir.')),
      );
      return;
    }
    final shuffled = List<Song>.from(_songs!)..shuffle();
    final playerVM = PlayerScope.of(context);
    playerVM.playSong(shuffled.first, queue: shuffled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reproducción aleatoria iniciada (${shuffled.length} temas)')),
    );
  }

  Future<void> _removeSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Quitar canción'),
        content: Text('¿Deseas quitar "${song.title}" de "${widget.playlist.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final libraryVM = LibraryScope.of(context);
      final ok = await libraryVM.removeSongFromPlaylist(widget.playlist.id, song.id);
      if (ok && mounted) {
        setState(() {
          _songs?.removeWhere((s) => s.id == song.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${song.title}" quitada de la playlist.')),
        );
      }
    }
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar Playlist'),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la playlist "${widget.playlist.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final libraryVM = LibraryScope.of(context);
      final ok = await libraryVM.deletePlaylist(widget.playlist.id);
      if (ok && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist "${widget.playlist.title}" eliminada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final songCount = _songs?.length ?? widget.playlist.songIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
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
        onRefresh: () => _loadSongs(forceRefresh: true),
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Cabecera decorativa de Playlist
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.25),
                    AppTheme.surface,
                  ],
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
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.playlist_play, color: AppTheme.primary, size: 44),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.playlist.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
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
                          onPressed: (_songs != null && _songs!.isNotEmpty) ? _playInOrder : null,
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
                          onPressed: (_songs != null && _songs!.isNotEmpty) ? _playShuffle : null,
                          icon: const Icon(Icons.shuffle, size: 20, color: AppTheme.primary),
                          label: const Text('Aleatorio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                Text(
                  '$songCount temas',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Estado de Carga / Error / Lista
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _loadSongs(forceRefresh: true),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_songs == null || _songs!.isEmpty)
              EmptyStateView(
                icon: Icons.music_off,
                title: 'Tu playlist no tiene canciones aún',
                description: 'Explora temas en la pantalla de inicio o perfiles de bandas y presiona el ícono "+" para sumarlos aquí.',
                actionLabel: 'Actualizar lista',
                onAction: () => _loadSongs(forceRefresh: true),
              )
            else
              ..._songs!.asMap().entries.map((entry) {
                final index = entry.key;
                final song = entry.value;
                final isCurrent = playerVM.currentSong?.id == song.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent,
                    ),
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
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondary,
                                        ),
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
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              playerVM.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppTheme.primary,
                              size: 26,
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      ),
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
                            isCurrent && playerVM.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: AppTheme.primary,
                            size: 30,
                          ),
                          onPressed: () {
                            if (isCurrent) {
                              playerVM.togglePlayPause();
                            } else {
                              playerVM.playSong(song, queue: _songs);
                            }
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                          onSelected: (val) {
                            if (val == 'remove') {
                              _removeSong(song);
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
                    onTap: () {
                      if (isCurrent) {
                        playerVM.togglePlayPause();
                      } else {
                        playerVM.playSong(song, queue: _songs);
                      }
                    },
                  ),
                );
              }),
            const SizedBox(height: 90), // Espacio para barra de reproducción flotante
          ],
        ),
      ),
    );
  }
}

