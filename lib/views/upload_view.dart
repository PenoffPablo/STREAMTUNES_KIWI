import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';
import 'package:streamtunes/widgets/waveform_painter.dart';

class UploadView extends StatefulWidget {
  const UploadView({super.key});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  UploadViewModel? _viewModel;
  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _durationController = TextEditingController(text: '180');
  String _selectedGenre = 'Rock';
  String? _selectedAlbumId;
  bool _runInBackground = false;

  String? _loadedBandId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repos = RepositoriesScope.of(context);
    _viewModel ??= UploadViewModel(
      songsRepo: repos.songsRepository,
      configRepo: repos.configRepository,
      deviceService: repos.deviceService,
    );

    final sessionVM = SessionScope.of(context);
    final currentBandId = sessionVM.activeBand?.id;
    if (currentBandId != null && currentBandId != _loadedBandId) {
      _loadedBandId = currentBandId;
      _viewModel!.loadBandQuota(currentBandId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _durationController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    final vm = _viewModel!;
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    final activeBand = sessionVM.activeBand;
    final repos = RepositoriesScope.of(context);
    final hasCamera = repos.deviceService.hasCamera;
    final isSpendCapActive = sessionVM.config.spendCapActive;

    // 1. Control de acceso: No autenticado
    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subir Música')),
        body: const EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Acceso para Músicos',
          description: 'Debes iniciar sesión con tu cuenta de músico para subir música independiente.',
        ),
      );
    }

    // 2. Control de acceso: No tiene banda registrada
    if (activeBand == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subir Música')),
        body: const EmptyStateView(
          icon: Icons.groups_outlined,
          title: 'Sin Banda Asignada',
          description: 'Tu usuario aún no está asociado como miembro o dueño de una banda.',
        ),
      );
    }

    // 3. Control de acceso: Banda en estado 'pending' o 'suspended'
    if (!activeBand.isApproved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subir Música')),
        body: EmptyStateView(
          icon: activeBand.isPending ? Icons.hourglass_top : Icons.block,
          title: activeBand.isPending
              ? 'Banda en Revisión por el Colectivo'
              : 'Banda Suspendida',
          description: activeBand.isPending
              ? 'Tu banda "${activeBand.name}" está en la lista de espera comunitaria. Un moderador del colectivo la revisará en breve para habilitar las subidas.'
              : 'La banda "${activeBand.name}" se encuentra suspendida temporariamente.',
        ),
      );
    }

    // 4. Control de acceso: Límite de presupuesto activo (pico viral de tráfico)
    if (isSpendCapActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subir Música')),
        body: const EmptyStateView(
          icon: Icons.flash_on,
          title: 'Subidas Pausadas por Alta Demanda',
          description: 'El colectivo activó el freno de emergencia por saturación de tráfico. Pronto reanudaremos las subidas.',
        ),
      );
    }

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Subir Música • ${activeBand.name}'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta de Cupos (X/20 temas y Y/2 álbumes)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: vm.hasReachedSongLimit ? AppTheme.errorRed : AppTheme.surfaceLight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('CUPO DE CANCIONES', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${vm.songCount} / ${vm.maxSongs}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: vm.hasReachedSongLimit ? AppTheme.errorRed : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: AppTheme.surfaceLight),
                      Column(
                        children: [
                          const Text('CUPO DE ÁLBUMES/EPS', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${vm.albumCount} / ${vm.maxAlbums}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: vm.hasReachedAlbumLimit ? AppTheme.accentOrange : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mensajes de Alerta o Error
                if (vm.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.errorRed),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vm.errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (vm.successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vm.successMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Selector de Audio y Análisis en Isolate
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.audiotrack, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'ARCHIVO DE AUDIO (.MP3, .WAV, .M4A)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tamaño máximo: 50 MB. Se verificará firma SHA-256 y picos de onda en un Isolate pesado.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      if (vm.isAnalyzing) ...[
                        const Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                            SizedBox(width: 12),
                            Text('Analizando cabeceras binarias y waveform en Isolate...', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                          ],
                        ),
                      ] else if (vm.analysisResult != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${vm.selectedAudio?.name} (${vm.analysisResult!.format.toUpperCase()} • ${(vm.analysisResult!.byteLength / (1024 * 1024)).toStringAsFixed(1)} MB)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: () => vm.pickAndAnalyzeAudio(),
                              child: const Text('Cambiar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 32,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: WaveformPainter(
                              peaks: vm.analysisResult!.waveformPeaks,
                              progress: 1.0,
                            ),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => vm.pickAndAnalyzeAudio(),
                          icon: const Icon(Icons.file_upload_outlined, color: AppTheme.primary),
                          label: const Text('Seleccionar archivo de audio'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Metadatos del Tema
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'METADATOS DE LA CANCIÓN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título del tema *',
                          hintText: 'Ej. Fuego en el Garaje',
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedGenre,
                              decoration: const InputDecoration(labelText: 'Género'),
                              items: const [
                                DropdownMenuItem(value: 'Rock', child: Text('Rock')),
                                DropdownMenuItem(value: 'Indie', child: Text('Indie')),
                                DropdownMenuItem(value: 'Pop', child: Text('Pop')),
                                DropdownMenuItem(value: 'Folk', child: Text('Folk')),
                                DropdownMenuItem(value: 'Hip-Hop', child: Text('Hip-Hop')),
                                DropdownMenuItem(value: 'Electrónica', child: Text('Electrónica')),
                                DropdownMenuItem(value: 'Jazz', child: Text('Jazz')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedGenre = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duración (segundos) *',
                                hintText: '>= 60s',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Álbum / EP opcional
                      if (vm.bandAlbums.isNotEmpty)
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedAlbumId,
                          decoration: const InputDecoration(labelText: 'Álbum o EP (Opcional)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Sencillo suelto (Sin álbum)')),
                            ...vm.bandAlbums.map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.title),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedAlbumId = val),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Portada: Cámara nativa vs Galería
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PORTADA DEL TEMA',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 80,
                              height: 80,
                              color: AppTheme.surfaceLight,
                              child: vm.selectedCoverPath != null && !kIsWeb
                                  ? Image.file(
                                      File(vm.selectedCoverPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.image, size: 40, color: AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasCamera) ...[
                                  ElevatedButton.icon(
                                    onPressed: () => vm.pickCoverPhoto(fromCamera: true),
                                    icon: const Icon(Icons.camera_alt, size: 16),
                                    label: const Text('Tomar con cámara'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.surfaceLight,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                OutlinedButton.icon(
                                  onPressed: () => vm.pickCoverPhoto(fromCamera: false),
                                  icon: const Icon(Icons.photo_library, size: 16),
                                  label: const Text('Elegir de galería'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Letra Sincronizada LRC
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.mic, color: AppTheme.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'LETRA SINCRONIZADA LRC (OPCIONAL)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Usa el formato estándar [mm:ss.xx] Verso para resaltar las palabras en el reproductor.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _lyricsController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '[00:15.20] El último tren se va perdiendo en la niebla\n[00:22.50] Luces de neón en la estación',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Opción de subida en segundo plano con Workmanager
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subir en segundo plano (Workmanager Android)'),
                  subtitle: const Text(
                    'Permite bloquear la pantalla o cambiar de app; se notificará al finalizar.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  value: _runInBackground,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) => setState(() => _runInBackground = val),
                ),
                const SizedBox(height: 20),

                // Botón de Publicar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: vm.isUploading || vm.isAnalyzing
                        ? null
                        : () async {
                            final title = _titleController.text.trim();
                            final duration = int.tryParse(_durationController.text) ?? 0;

                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor ingresa el título de la canción.')),
                              );
                              return;
                            }

                            final success = await vm.publishSong(
                              bandId: activeBand.id,
                              bandName: activeBand.name,
                              title: title,
                              genre: _selectedGenre,
                              albumId: _selectedAlbumId,
                              lyricsLrc: _lyricsController.text.trim().isNotEmpty
                                  ? _lyricsController.text.trim()
                                  : null,
                              durationSeconds: duration,
                              runInBackground: _runInBackground,
                            );

                            if (success && mounted) {
                              _titleController.clear();
                              _lyricsController.clear();
                              _durationController.text = '180';
                            }
                          },
                    child: vm.isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                              SizedBox(width: 12),
                              Text('Publicando canción...'),
                            ],
                          )
                        : const Text('Publicar Canción en StreamTunes'),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}
