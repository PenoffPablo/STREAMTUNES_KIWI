import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';

/// Edición del perfil público de la banda: foto, nombre, género, ciudad,
/// biografía, meta de recaudación, redes y tienda de merch.
class EditBandProfileView extends StatefulWidget {
  const EditBandProfileView({super.key, required this.viewModel});

  final BandDashboardViewModel viewModel;

  @override
  State<EditBandProfileView> createState() => _EditBandProfileViewState();
}

class _EditBandProfileViewState extends State<EditBandProfileView> {
  late final Band _band = widget.viewModel.band!;
  late final _name = TextEditingController(text: _band.name);
  late final _location = TextEditingController(text: _band.location ?? '');
  late final _bio = TextEditingController(text: _band.bio ?? '');
  late final _goal = TextEditingController(text: _band.donationGoal.toStringAsFixed(0));
  late final _merch = TextEditingController(text: _band.merchUrl ?? '');
  late final Map<String, TextEditingController> _social = {
    for (final key in kBandSocialNetworks.keys)
      key: TextEditingController(text: (_band.socialLinks[key] as String?) ?? ''),
  };
  late String _genre = kBandGenres.contains(_band.genre) ? _band.genre : 'Otro';
  String? _newCoverPath;

  @override
  void dispose() {
    for (final c in [_name, _location, _bio, _goal, _merch, ..._social.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final path = await widget.viewModel.pickPhoto();
    if (path != null && mounted) setState(() => _newCoverPath = path);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final session = SessionScope.read(context);
    final goal = double.tryParse(_goal.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? -1;

    final ok = await widget.viewModel.updateProfile(
      name: _name.text,
      genre: _genre,
      location: _location.text,
      bio: _bio.text,
      donationGoal: goal,
      socialLinks: {for (final e in _social.entries) e.key: e.value.text},
      merchUrl: _merch.text,
      newCoverPath: _newCoverPath,
    );
    if (!ok || !mounted) return;
    // El nombre y la foto también se ven en Cuenta y en el inicio.
    await session.refreshUser();
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Perfil de la banda actualizado.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil de la banda')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          final saving = vm.isSavingProfile;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (vm.profileError != null) ...[
                ErrorBanner(message: vm.profileError!),
                const SizedBox(height: 12),
              ],
              _CoverEditor(
                currentUrl: _band.coverUrl,
                newPath: _newCoverPath,
                onPick: saving ? null : _pickCover,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: BandDashboardViewModel.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre de la banda *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _genre,
                decoration: const InputDecoration(labelText: 'Género'),
                items: [for (final g in kBandGenres) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: saving ? null : (g) => setState(() => _genre = g ?? _genre),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bio,
                maxLines: 5,
                maxLength: BandDashboardViewModel.maxBioLength,
                decoration: const InputDecoration(
                  labelText: 'Biografía',
                  hintText: 'Contá quiénes son, qué tocan y desde cuándo.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _goal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Meta de recaudación (ARS)',
                  helperText: 'Se muestra como barra de progreso en tu perfil.',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 20),
              const Text('REDES Y TIENDA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              for (final e in kBandSocialNetworks.entries) ...[
                TextField(
                  controller: _social[e.key],
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: e.value, hintText: 'Link a tu ${e.value}'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _merch,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Tienda de merch', hintText: 'Link a tu tienda'),
              ),
              const SizedBox(height: 8),
              const Text(
                'La dirección de tu banda (la del QR) no cambia aunque cambies el nombre, así los QR impresos siguen funcionando.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save),
                  label: Text(saving ? 'Guardando...' : 'Guardar cambios'),
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

/// Foto de la banda: la actual, o la nueva elegida (todavía sin guardar).
class _CoverEditor extends StatelessWidget {
  const _CoverEditor({required this.currentUrl, required this.newPath, required this.onPick});

  final String? currentUrl;
  final String? newPath;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (newPath != null && !kIsWeb) {
      image = Image.file(File(newPath!), fit: BoxFit.cover);
    } else if (currentUrl != null && currentUrl!.startsWith('http')) {
      image = Image.network(
        currentUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.groups, size: 40, color: AppTheme.textSecondary),
      );
    } else {
      image = const Icon(Icons.groups, size: 40, color: AppTheme.textSecondary);
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(width: 96, height: 96, color: AppTheme.surfaceLight, child: image),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(newPath == null ? 'Cambiar foto' : 'Elegir otra'),
              ),
              if (newPath != null)
                const Text('Se guarda al tocar "Guardar cambios".',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
