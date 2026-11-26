import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_registration/view_models/band_registration_view_model.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';

/// Formulario para registrar una banda. Al enviarlo, la banda queda en
/// revisión hasta que un moderador la apruebe.
class BandRegistrationView extends StatefulWidget {
  const BandRegistrationView({super.key});

  @override
  State<BandRegistrationView> createState() => _BandRegistrationViewState();
}

class _BandRegistrationViewState extends State<BandRegistrationView> {
  late final BandRegistrationViewModel _viewModel;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createBandRegistrationViewModel(SessionScope.read(context));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await _viewModel.submit(
      name: _nameController.text,
      location: _locationController.text,
      bio: _bioController.text,
    );
    if (!ok || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text(
          '¡Listo! "${_nameController.text.trim()}" quedó en revisión. Te avisamos cuando la aprueben.',
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi banda')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final vm = _viewModel;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _ReviewNotice(),
              const SizedBox(height: 16),
              if (vm.errorMessage != null) ...[
                ErrorBanner(message: vm.errorMessage!),
                const SizedBox(height: 12),
              ],
              _BandCoverPicker(
                coverPath: vm.coverPath,
                hasCamera: vm.hasCamera,
                onPick: (fromCamera) => vm.pickCover(fromCamera: fromCamera),
                onRemove: vm.removeCover,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                maxLength: BandRegistrationViewModel.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre de la banda *', hintText: 'Ej. Los Fuzzers'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: vm.genre,
                decoration: const InputDecoration(labelText: 'Género'),
                items: [for (final g in kBandGenres) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: vm.isSubmitting ? null : (g) => g == null ? null : vm.selectGenre(g),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad', hintText: 'Ej. Buenos Aires'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 4,
                maxLength: BandRegistrationViewModel.maxBioLength,
                decoration: const InputDecoration(
                  labelText: 'Biografía',
                  hintText: 'Contá quiénes son, qué tocan y desde cuándo.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: vm.isSubmitting ? null : _submit,
                  icon: vm.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.send),
                  label: Text(vm.isSubmitting ? 'Enviando...' : 'Enviar a revisión'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Explica qué pasa después de registrar la banda.
class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(80)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Un moderador revisa cada banda (que la música sea propia y los datos, reales). '
              'Cuando la aprueben vas a ver las pestañas "Subir" y "Mi Banda" para publicar tus temas.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de la banda (opcional): galería o cámara.
class _BandCoverPicker extends StatelessWidget {
  const _BandCoverPicker({
    required this.coverPath,
    required this.hasCamera,
    required this.onPick,
    required this.onRemove,
  });

  final String? coverPath;
  final bool hasCamera;
  final ValueChanged<bool> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 88,
            height: 88,
            color: AppTheme.surfaceLight,
            child: path != null && !kIsWeb
                ? Image.file(File(path), fit: BoxFit.cover)
                : const Icon(Icons.groups, size: 40, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: () => onPick(false),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galería'),
              ),
              if (hasCamera)
                OutlinedButton.icon(
                  onPressed: () => onPick(true),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Cámara'),
                ),
              if (path != null) TextButton(onPressed: onRemove, child: const Text('Quitar')),
            ],
          ),
        ),
      ],
    );
  }
}
