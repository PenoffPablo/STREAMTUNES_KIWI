import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/band_stats.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';

class BandDashboardView extends StatefulWidget {
  const BandDashboardView({super.key});

  @override
  State<BandDashboardView> createState() => _BandDashboardViewState();
}

class _BandDashboardViewState extends State<BandDashboardView> {
  BandDashboardViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionVM = SessionScope.of(context);
    final activeBand = sessionVM.activeBand;

    if (activeBand != null && (_viewModel == null || _viewModel!.bandId != activeBand.id)) {
      final repos = RepositoriesScope.of(context);
      _viewModel?.dispose();
      _viewModel = BandDashboardViewModel(
        bandsRepo: repos.bandsRepository,
        songsRepo: repos.songsRepository,
        bandId: activeBand.id,
      );
      _viewModel!.loadDashboard();
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  void _showAddEventDialog() {
    final titleCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Buenos Aires');
    final ticketCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Agregar Fecha de Show'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Nombre del Evento *')),
                  const SizedBox(height: 10),
                  TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Lugar / Venue *')),
                  const SizedBox(height: 10),
                  TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Ciudad *')),
                  const SizedBox(height: 10),
                  TextField(controller: ticketCtrl, decoration: const InputDecoration(labelText: 'Link de Entradas (Opcional)')),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isNotEmpty && venueCtrl.text.trim().isNotEmpty) {
                    await _viewModel?.addEvent(
                      title: titleCtrl.text.trim(),
                      venue: venueCtrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      date: selectedDate,
                      ticketUrl: ticketCtrl.text.trim().isNotEmpty ? ticketCtrl.text.trim() : null,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPhotoDialog() {
    final urlCtrl = TextEditingController(text: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819');
    final capCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Sumar Foto de Recital'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL de la Foto *')),
            const SizedBox(height: 10),
            TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Epígrafe (Opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (urlCtrl.text.trim().isNotEmpty) {
                await _viewModel?.addPhoto(
                  photoUrl: urlCtrl.text.trim(),
                  caption: capCtrl.text.trim().isNotEmpty ? capCtrl.text.trim() : null,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEditMerchDialog(Band band) {
    final merchCtrl = TextEditingController(text: band.merchUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Link de Tienda de Merch'),
        content: TextField(
          controller: merchCtrl,
          decoration: const InputDecoration(
            labelText: 'URL externa (remeras, vinilos)',
            hintText: 'https://mitienda.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _viewModel?.updateMerchUrl(merchCtrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
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
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _viewModel?.loadDashboard(),
              ),
            ],
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
                    _buildDailyMetricsSection(stats),
                    const SizedBox(height: 16),

                    // 3. Agenda de Fechas ABM
                    _buildEventsCard(_viewModel!.events),
                    const SizedBox(height: 16),

                    // 5. Galería de Fotos de Shows
                    _buildPhotosCard(_viewModel!.photos),
                    const SizedBox(height: 16),

                    // 6. Configuración de Tienda de Merch
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.primary),
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 160.0,
              backgroundColor: Colors.white,
            ),
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

  Widget _buildDailyMetricsSection(BandAggregatedStats? stats) {
    if (_viewModel!.isLoadingMetrics) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
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
      children: [
        _buildServerStats(stats),
        const SizedBox(height: 16),
        _buildTopFansCard(_viewModel!.topFans),
      ],
    );
  }

  Widget _buildServerStats(BandAggregatedStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MÉTRICAS DEL SERVIDOR (POSTGRESQL RPC)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
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
            ...stats.topSongs.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(s.title, style: const TextStyle(fontSize: 13))),
                      Text('${s.playCount} plays', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildTopFansCard(List<TopFanStat> fans) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP 10 FANS (RESPETANDO OPT-IN PRIVACIDAD)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          if (fans.isEmpty)
            const Text('Sin actividad registrada.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
          else
            ...fans.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('#${f.rank}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
                      Text('${f.minutesListened} min', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildEventsCard(List<BandEvent> events) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AGENDA DE SHOWS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              IconButton(icon: const Icon(Icons.add, color: AppTheme.primary), onPressed: _showAddEventDialog),
            ],
          ),
          if (events.isEmpty)
            const Text('No hay fechas cargadas.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
          else
            ...events.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${e.venue} • ${e.city} (${e.eventDate.day}/${e.eventDate.month})'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                    onPressed: () => _viewModel?.deleteEvent(e.id),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(List<BandPhoto> photos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FOTOS DE SHOWS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              IconButton(icon: const Icon(Icons.add_a_photo, color: AppTheme.primary), onPressed: _showAddPhotoDialog),
            ],
          ),
          if (photos.isEmpty)
            const Text('No hay fotos en la galería.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
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
