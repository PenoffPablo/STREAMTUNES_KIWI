import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/upload/widgets/audio_picker_card.dart';
import 'package:streamtunes/ui/upload/widgets/cover_picker_card.dart';
import 'package:streamtunes/ui/upload/widgets/lyrics_field_card.dart';
import 'package:streamtunes/ui/upload/widgets/upload_quota_card.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/upload/view_models/upload_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';

class UploadView extends StatefulWidget {
  const UploadView({super.key});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  late final UploadViewModel _viewModel;
  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _durationController = TextEditingController(text: '180');
  String _selectedGenre = 'Rock';
  String? _selectedAlbumId;
  bool _runInBackground = false;

  String? _loadedBandId;

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createUploadViewModel();
  }

  /// Se re-ejecuta cuando cambia la sesión: si cambió la banda activa, recarga su cupo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBandId = SessionScope.of(context).activeBand?.id;
    if (currentBandId != null && currentBandId != _loadedBandId) {
      _loadedBandId = currentBandId;
      _viewModel.loadBandQuota(currentBandId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _durationController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Valida el título y publica el tema (o lo deja en segundo plano).
  Future<void> _publish(Band activeBand) async {
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text) ?? 0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor ingresa el título de la canción.')));
      return;
    }

    final success = await _viewModel.publishSong(
      bandId: activeBand.id,
      bandName: activeBand.name,
      title: title,
      genre: _selectedGenre,
      albumId: _selectedAlbumId,
      lyricsLrc: _lyricsController.text.trim().isNotEmpty ? _lyricsController.text.trim() : null,
      durationSeconds: duration,
      runInBackground: _runInBackground,
    );

    if (success && mounted) {
      _titleController.clear();
      _lyricsController.clear();
      _durationController.text = '180';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _viewModel;
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    final activeBand = sessionVM.activeBand;
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
          title: activeBand.isPending ? 'Banda en Revisión por el Colectivo' : 'Banda Suspendida',
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
          description:
              'El colectivo activó el freno de emergencia por saturación de tráfico. Pronto reanudaremos las subidas.',
        ),
      );
    }

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text('Subir Música • ${activeBand.name}')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UploadQuotaCard(viewModel: vm),
                const SizedBox(height: 16),

                // Mensajes de Alerta o Error
                if (vm.errorMessage != null) ...[ErrorBanner(message: vm.errorMessage!), const SizedBox(height: 16)],

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

                // 1. Audio: análisis en un worker isolate
                AudioPickerCard(viewModel: vm),
                const SizedBox(height: 16),

                // 2. Metadatos del Tema
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
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
                              decoration: const InputDecoration(labelText: 'Duración (segundos) *', hintText: '>= 60s'),
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
                            ...vm.bandAlbums.map((a) => DropdownMenuItem(value: a.id, child: Text(a.title))),
                          ],
                          onChanged: (val) => setState(() => _selectedAlbumId = val),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Portada: cámara nativa o galería
                CoverPickerCard(viewModel: vm),
                const SizedBox(height: 16),

                // 4. Letra sincronizada LRC
                LyricsFieldCard(controller: _lyricsController),
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
                    onPressed: vm.isUploading || vm.isAnalyzing ? null : () => _publish(activeBand),
                    child: vm.isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              ),
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
