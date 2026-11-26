import 'dart:io';

import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/ui/core/widgets/text_input_dialog.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/dashboard_dialogs.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/band_qr_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/daily_metrics_section.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/events_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/kiwi_account_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/band_profile_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/edit_band_profile_view.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/merch_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/photos_card.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/songs_management_card.dart';

class BandDashboardView extends StatefulWidget {
  const BandDashboardView({super.key});

  @override
  State<BandDashboardView> createState() => _BandDashboardViewState();
}

class _BandDashboardViewState extends State<BandDashboardView> {
  BandDashboardViewModel? _viewModel;

  /// Acá didChangeDependencies es el lugar correcto: el ViewModel depende de la
  /// banda activa de la sesión. Si cambia la banda, se libera el VM anterior y
  /// se crea uno nuevo (ciclo de vida completo: crear -> usar -> dispose).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeBand = SessionScope.of(context).activeBand;
    if (activeBand != null && _viewModel?.bandId != activeBand.id) {
      _viewModel?.dispose();
      _viewModel = DependenciesScope.of(context).createBandDashboardViewModel(activeBand.id)..loadDashboard();
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  void _showResult(bool ok, String okText, String errorText) {
    if (!mounted) return;
    if (!ok) {
      showErrorSnackBar(context, message: errorText.isEmpty ? kUnexpectedErrorMessage : errorText);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text(okText, style: const TextStyle(color: Colors.black)),
      ),
    );
  }

  Future<void> _showAddEventDialog() async {
    final data = await AddEventDialog.show(context);
    if (data == null) return;
    await _viewModel?.addEvent(
      title: data.title,
      venue: data.venue,
      city: data.city,
      date: data.date,
      ticketUrl: data.ticketUrl,
    );
  }

  Future<void> _showAddPhotoDialog() async {
    final vm = _viewModel;
    if (vm == null) return;
    final pickedPath = await vm.pickPhoto();
    if (pickedPath == null || !mounted) return;

    final caption = await TextInputDialog.show(
      context,
      title: 'Foto de Recital',
      label: 'Epígrafe o Recital (Opcional)',
      hint: 'Ej. Sótano en San Telmo - Octubre',
      confirmLabel: 'Subir Foto',
      allowEmpty: true,
      header: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(pickedPath),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 160,
            color: AppTheme.surfaceLight,
            child: const Center(child: Icon(Icons.image, size: 48, color: AppTheme.textSecondary)),
          ),
        ),
      ),
    );
    if (caption == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Subiendo foto del recital...'), duration: Duration(seconds: 2)));
    await vm.addPhoto(photoUrl: pickedPath, caption: caption.isEmpty ? null : caption);
    _showResult(vm.errorMessage == null, '¡Foto añadida a la galería con éxito!', vm.errorMessage ?? '');
  }

  Future<void> _showEditSongDialog(Song song) async {
    final data = await EditSongDialog.show(context, song);
    if (data == null) return;
    final ok =
        await _viewModel?.editSong(songId: song.id, title: data.title, genre: data.genre, lyricsLrc: data.lyricsLrc) ??
        false;
    _showResult(
      ok,
      '¡Canción "${data.title}" actualizada con éxito!',
      _viewModel?.errorMessage ?? 'No se pudo actualizar la canción.',
    );
  }

  Future<void> _confirmDeleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('¿Eliminar Canción?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente "${song.title}"?\n\nEsta acción borrará el tema de la plataforma y liberará tu cupo de canciones (actualmente ${_viewModel?.songs.length ?? 0}/20).',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _viewModel?.deleteSong(song.id) ?? false;
    _showResult(
      ok,
      'Canción "${song.title}" eliminada y cupo liberado.',
      _viewModel?.errorMessage ?? 'No se pudo eliminar la canción.',
    );
  }

  Future<void> _showEditMerchDialog(Band band) async {
    final url = await TextInputDialog.show(
      context,
      title: 'Link de Tienda de Merch',
      label: 'URL externa (remeras, vinilos)',
      hint: 'https://mitienda.com',
      initialValue: band.merchUrl ?? '',
      allowEmpty: true,
      keyboardType: TextInputType.url,
    );
    if (url != null) await _viewModel?.updateMerchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final activeBand = sessionVM.activeBand;

    if (activeBand == null || _viewModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel Mi Banda')),
        body: const EmptyStateView(
          icon: Icons.groups_outlined,
          title: 'Sin Banda Asignada',
          description: 'No tienes una banda asociada activa en tu perfil.',
        ),
      );
    }

    return ListenableBuilder(
      listenable: _viewModel!,
      builder: (context, _) {
        final band = _viewModel!.band ?? activeBand;

        return Scaffold(
          appBar: AppBar(
            title: Text('Panel • ${band.name}'),
            actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _viewModel?.loadDashboard())],
          ),
          body: _viewModel!.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Perfil público de la banda (foto, nombre, bio, redes): editable
                    BandProfileCard(
                      band: band,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => EditBandProfileView(viewModel: _viewModel!)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Tarjeta con QR Generado Offline para Recitales
                    BandQrCard(band: band),
                    const SizedBox(height: 16),

                    // 2. Métricas Diarias del Artista (RPC band_aggregated_stats y band_top_fans)
                    if (_viewModel!.metricsError != null) ...[
                      // Un fallo de red ya no se ve como "0 reproducciones".
                      ErrorBanner(
                        warning: true,
                        message: _viewModel!.metricsError!,
                        onRetry: _viewModel!.loadDailyMetrics,
                      ),
                      const SizedBox(height: 8),
                    ],
                    DailyMetricsSection(viewModel: _viewModel!),
                    const SizedBox(height: 16),

                    // Estado de cuenta con KIWI (aportes cobrados y liquidaciones).
                    // Si falla la actualización se conserva el último saldo y se avisa.
                    if (_viewModel!.accountError != null) ...[
                      ErrorBanner(
                        warning: true,
                        message: _viewModel!.accountError!,
                        onRetry: _viewModel!.refreshAccount,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_viewModel!.balance != null) ...[
                      KiwiAccountCard(
                        balance: _viewModel!.balance!,
                        payouts: _viewModel!.payouts,
                        commissionPct: sessionVM.config.kiwiCommissionPct,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. Mis Canciones Subidas (Gestión, Edición y Borrado de catálogo)
                    SongsManagementCard(
                      songs: _viewModel!.songs,
                      onEdit: _showEditSongDialog,
                      onDelete: _confirmDeleteSong,
                    ),
                    const SizedBox(height: 16),

                    // 4. Agenda de Fechas ABM
                    EventsCard(
                      events: _viewModel!.events,
                      onAdd: _showAddEventDialog,
                      onDelete: (e) => _viewModel?.deleteEvent(e.id),
                    ),
                    const SizedBox(height: 16),

                    // 5. Galería de Fotos de Shows
                    PhotosCard(photos: _viewModel!.photos, onAdd: _showAddPhotoDialog),
                    const SizedBox(height: 16),

                    // 6. Configuración de Tienda de Merch
                    MerchCard(merchUrl: band.merchUrl, onEdit: () => _showEditMerchDialog(band)),
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }
}
