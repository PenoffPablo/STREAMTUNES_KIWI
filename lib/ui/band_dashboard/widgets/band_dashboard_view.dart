import 'dart:io';

import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/ui/core/widgets/text_input_dialog.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/dashboard_dialogs.dart';

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

  Future<void> _exportHistory() async {
    final vm = _viewModel;
    if (vm == null) return;
    await vm.exportHistoryInIsolate();
    if (!mounted) return;
    final summary = vm.exportSummary;
    if (summary == null) {
      _showResult(false, '', vm.errorMessage ?? 'No se pudo generar el reporte.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Reporte generado'),
        content: SelectableText(summary, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar'))],
      ),
    );
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
        final stats = _viewModel!.stats;

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
                    // 1. Tarjeta con QR Generado Offline para Recitales
                    _buildQrCard(band),
                    const SizedBox(height: 16),

                    // 2. Métricas Diarias del Artista (RPC band_aggregated_stats y band_top_fans)
                    if (_viewModel!.metricsError != null) ...[
                      // Un fallo de red ya no se ve como "0 reproducciones".
                      ErrorBanner(
                        warning: true,
                        message: _viewModel!.metricsError!,
                        onRetry: () => _viewModel!.loadDailyMetrics(forceRefresh: true),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildDailyMetricsSection(stats),
                    const SizedBox(height: 12),
                    _buildExportCard(_viewModel!),
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
                    if (_viewModel!.balance != null) ...[_buildAccountCard(_viewModel!), const SizedBox(height: 16)],

                    // 3. Mis Canciones Subidas (Gestión, Edición y Borrado de catálogo)
                    _buildSongsManagementCard(_viewModel!.songs),
                    const SizedBox(height: 16),

                    // 4. Agenda de Fechas ABM
                    _buildEventsCard(_viewModel!.events),
                    const SizedBox(height: 16),

                    // 5. Galería de Fotos de Shows
                    _buildPhotosCard(_viewModel!.photos),
                    const SizedBox(height: 16),

                    // 6. Configuración de Tienda de Merch
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tienda de Merch Externa', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  band.merchUrl ?? 'No configurada aún',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showEditMerchDialog(band),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Editar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildQrCard(Band band) {
    final qrData = 'https://streamtunes.app/band/${band.slug}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CÓDIGO QR INTELIGENTE (RECITALES & SÓTANOS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Escaneo universal: si el fan tiene instalada StreamTunes abre la app y te sigue al instante. Si no la tiene instalada, lo lleva directo a descargarla.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: qrData, version: QrVersions.auto, size: 160.0, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            qrData,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  static String _money(double v) => '\$${v.toStringAsFixed(0)}';
  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Estado de cuenta con KIWI. KIWI cobra los aportes en su cuenta de Mercado
  /// Pago y después le transfiere a la banda su saldo.
  Widget _buildAccountCard(BandDashboardViewModel vm) {
    final b = vm.balance!;
    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'TUS APORTES CON KIWI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Recaudado (neto)', _money(b.netCollected)),
              stat('Ya cobrado', _money(b.paid)),
              stat('A cobrar', _money(b.pending), color: b.hasPending ? AppTheme.primary : null),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los fans pagan con Mercado Pago a la cuenta de KIWI. Comisión de Mercado Pago '
            'descontada: ${_money(b.mercadoPagoFees)}.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          if (vm.payouts.isNotEmpty) ...[
            const Divider(color: AppTheme.surfaceLight, height: 20),
            const Text('Últimos pagos de KIWI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            for (final p in vm.payouts.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_date(p.paidAt)}${p.reference != null ? ' · Op. ${p.reference}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(_money(p.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Reporte de historial (CSV firmado) generado en otro isolate. Máx. 1 por día.
  Widget _buildExportCard(BandDashboardViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.file_download_outlined, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vm.canExportToday
                  ? 'Exportar historial de reproducciones (CSV firmado)'
                  : 'Reporte de hoy ya generado. Disponible de nuevo en 24 h.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          vm.isExporting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                )
              : TextButton(onPressed: vm.canExportToday ? _exportHistory : null, child: const Text('Exportar')),
        ],
      ),
    );
  }

  Widget _buildDailyMetricsSection(BandAggregatedStats? stats) {
    if (_viewModel!.isLoadingMetrics) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 12),
              Text(
                'Cargando métricas consolidadas del servidor...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (stats == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'MÉTRICAS DIARIAS DEL ARTISTA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: const Text(
                    '1 Consulta / Día',
                    style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Consolidado de reproducciones totales, minutos de escucha, canciones más escuchadas y ranking de fans de la banda.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _viewModel!.loadDailyMetrics(),
                icon: const Icon(Icons.bar_chart, size: 20),
                label: const Text(
                  'Ver mis métricas diarias',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [_buildServerStats(stats), const SizedBox(height: 16), _buildTopFansCard(_viewModel!.topFans)],
    );
  }

  Widget _buildServerStats(BandAggregatedStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MÉTRICAS DEL SERVIDOR (POSTGRESQL RPC)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withAlpha(80)),
                ),
                child: const Text(
                  '1 Consulta / Día',
                  style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _viewModel?.isMetricsFromCache == true
                ? 'Consolidado diario en caché local. Próxima actualización en ${_viewModel?.timeUntilNextRefresh?.inHours ?? 0} hs para evitar saturar el servidor colectivo.'
                : 'Métricas consolidadas actualizadas hoy desde PostgreSQL.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricTile('REPRODUCCIONES', '${stats.totalPlays}'),
              _metricTile('MINUTOS GLOBALES', '${stats.totalMinutes}'),
              _metricTile('ÚLTIMOS 7 DÍAS', '${stats.last7DaysPlays}'),
            ],
          ),
          if (stats.topSongs.isNotEmpty) ...[
            const Divider(height: 24, color: AppTheme.surfaceLight),
            const Text('Top 5 Canciones de la Banda:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...stats.topSongs.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(s.title, style: const TextStyle(fontSize: 13))),
                    Text(
                      '${s.playCount} plays',
                      style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildTopFansCard(List<TopFanStat> fans) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP 10 FANS (RESPETANDO OPT-IN PRIVACIDAD)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (fans.isEmpty)
            const Text(
              'Sin actividad registrada.',
              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            )
          else
            ...fans.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '#${f.rank}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.isPublic ? f.displayName : 'Fan anónimo (Privado)',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: f.isPublic ? FontStyle.normal : FontStyle.italic,
                          color: f.isPublic ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${f.minutesListened} min',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongsManagementCard(List<Song> songs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MIS CANCIONES SUBIDAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '${songs.length}/20 Temas',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Administra tu catálogo: edita el título, género o letra sincronizada (LRC), o elimina una canción si la subiste por error para liberar tu cupo.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (songs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Aún no has subido canciones con esta banda.\nUsa la pestaña "Subir" del menú inferior para publicar tu música.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...songs.map((song) {
              final minutes = song.durationSeconds ~/ 60;
              final seconds = (song.durationSeconds % 60).toString().padLeft(2, '0');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: AppTheme.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: Colors.black26,
                      child: song.coverUrl != null
                          ? Image.network(
                              song.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: AppTheme.primary),
                            )
                          : const Icon(Icons.music_note, color: AppTheme.primary),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${song.genre} • $minutes:$seconds • ${song.playCount} plays',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditSongDialog(song);
                      } else if (val == 'delete') {
                        _confirmDeleteSong(song);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: AppTheme.primary),
                            SizedBox(width: 10),
                            Text('Editar metadatos'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Eliminar canción', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEventsCard(List<BandEvent> events) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AGENDA DE SHOWS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppTheme.primary),
                onPressed: _showAddEventDialog,
              ),
            ],
          ),
          if (events.isEmpty)
            const Text(
              'No hay fechas cargadas.',
              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            )
          else
            ...events.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${e.venue} • ${e.city} (${e.eventDate.day}/${e.eventDate.month})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                  onPressed: () => _viewModel?.deleteEvent(e.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(List<BandPhoto> photos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FOTOS DE SHOWS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.add_a_photo, color: AppTheme.primary),
                onPressed: _showAddPhotoDialog,
              ),
            ],
          ),
          if (photos.isEmpty)
            const Text(
              'No hay fotos en la galería.',
              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final p = photos[idx];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 120,
                      color: AppTheme.surfaceLight,
                      child: Image.network(
                        p.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
