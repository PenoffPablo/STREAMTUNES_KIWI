import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Métricas diarias del artista: botón para pedirlas (1 consulta por día),
/// estado de carga y, cuando están, totales del servidor y top fans.
class DailyMetricsSection extends StatelessWidget {
  const DailyMetricsSection({super.key, required this.viewModel});

  final BandDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final stats = viewModel.stats;
    if (viewModel.isLoadingMetrics) {
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
                onPressed: () => viewModel.loadDailyMetrics(),
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
        ServerStatsCard(
          stats: stats,
          fromCache: viewModel.isMetricsFromCache,
          hoursUntilRefresh: viewModel.timeUntilNextRefresh?.inHours ?? 0,
        ),
        const SizedBox(height: 16),
        TopFansCard(fans: viewModel.topFans),
      ],
    );
  }
}

/// Totales que calcula PostgreSQL (RPC band_aggregated_stats).
class ServerStatsCard extends StatelessWidget {
  const ServerStatsCard({super.key, required this.stats, required this.fromCache, required this.hoursUntilRefresh});

  final BandAggregatedStats stats;
  final bool fromCache;
  final int hoursUntilRefresh;

  @override
  Widget build(BuildContext context) {
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
            fromCache
                ? 'Consolidado diario en caché local. Próxima actualización en $hoursUntilRefresh hs para evitar saturar el servidor colectivo.'
                : 'Métricas consolidadas actualizadas hoy desde PostgreSQL.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricTile('REPRODUCCIONES', '${stats.totalPlays}'),
              _MetricTile('MINUTOS GLOBALES', '${stats.totalMinutes}'),
              _MetricTile('ÚLTIMOS 7 DÍAS', '${stats.last7DaysPlays}'),
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
}

/// Ranking de fans: los perfiles privados se muestran anónimos.
class TopFansCard extends StatelessWidget {
  const TopFansCard({super.key, required this.fans});

  final List<TopFanStat> fans;

  @override
  Widget build(BuildContext context) {
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
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
}
