import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_overview.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Color y texto de cada estado de banda.
(Color, String, IconData) bandStatusStyle(BandStatus status) => switch (status) {
      BandStatus.approved => (AppTheme.primary, 'Aprobada', Icons.verified),
      BandStatus.pending => (AppTheme.accentOrange, 'Pendiente', Icons.hourglass_top),
      BandStatus.suspended => (AppTheme.errorRed, 'Suspendida', Icons.block),
    };

/// Una banda en el panel "Bandas del colectivo": datos, estado y acciones.
class BandOverviewCard extends StatelessWidget {
  const BandOverviewCard({
    super.key,
    required this.overview,
    required this.busy,
    required this.onSetStatus,
    required this.onOpenProfile,
  });

  final BandOverview overview;
  final bool busy;
  final ValueChanged<BandStatus> onSetStatus;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final b = overview.band;
    final (color, label, icon) = bandStatusStyle(b.status);
    final details = [
      b.genre,
      if (b.location?.isNotEmpty ?? false) b.location!,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: AppTheme.surfaceLight,
                    child: b.coverUrl != null && b.coverUrl!.startsWith('http')
                        ? Image.network(
                            b.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.groups, color: AppTheme.textSecondary),
                          )
                        : const Icon(Icons.groups, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(details, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Stat(Icons.people_outline, '${b.followerCount} seguidores'),
                _Stat(Icons.music_note_outlined, '${overview.songCount} temas'),
                _Stat(Icons.event_outlined, 'Alta ${_date(b.createdAt)}'),
                if (overview.ownerName != null) _Stat(Icons.person_outline, overview.ownerName!),
              ],
            ),
            if (b.bio?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                b.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      children: [
                        TextButton(onPressed: onOpenProfile, child: const Text('Ver perfil')),
                        ...switch (b.status) {
                          BandStatus.pending => [
                              TextButton(
                                onPressed: () => onSetStatus(BandStatus.suspended),
                                child: const Text('Rechazar', style: TextStyle(color: AppTheme.errorRed)),
                              ),
                              ElevatedButton(
                                onPressed: () => onSetStatus(BandStatus.approved),
                                child: const Text('Aprobar'),
                              ),
                            ],
                          BandStatus.approved => [
                              OutlinedButton(
                                onPressed: () => onSetStatus(BandStatus.suspended),
                                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
                                child: const Text('Suspender'),
                              ),
                            ],
                          BandStatus.suspended => [
                              ElevatedButton(
                                onPressed: () => onSetStatus(BandStatus.approved),
                                child: const Text('Reactivar'),
                              ),
                            ],
                        },
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}
