import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Banda en espera de aprobación, con aprobar y rechazar.
class PendingBandCard extends StatelessWidget {
  const PendingBandCard({super.key, required this.band, required this.onApprove, required this.onReject});

  final Band band;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: AppTheme.surfaceLight,
                    child: band.coverUrl != null
                        ? Image.network(
                            band.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.groups),
                          )
                        : const Icon(Icons.groups),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(band.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${band.genre} • ${band.location ?? "Sin ubicación"}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(
                        'Slug: /band/${band.slug}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (band.bio != null) ...[
              const SizedBox(height: 8),
              Text(band.bio!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => onReject(),
                  child: const Text('Rechazar', style: TextStyle(color: AppTheme.errorRed)),
                ),
                ElevatedButton(onPressed: () => onApprove(), child: const Text('Aprobar Banda')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
