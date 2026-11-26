import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Resumen del perfil público de la banda con el botón para editarlo.
class BandProfileCard extends StatelessWidget {
  const BandProfileCard({super.key, required this.band, required this.onEdit});

  final Band band;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final networks = [
      for (final e in kBandSocialNetworks.entries)
        if ((band.socialLinks[e.key] as String?)?.isNotEmpty ?? false) e.value,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AppTheme.surfaceLight,
                  child: band.coverUrl != null && band.coverUrl!.startsWith('http')
                      ? Image.network(
                          band.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.groups, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.groups, size: 32, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      band.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [band.genre, if (band.location != null) band.location!].join(' • '),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (networks.isNotEmpty)
                      Text(
                        networks.join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            band.bio?.isNotEmpty == true ? band.bio! : 'Todavía no hay biografía. Contale a tus fans quiénes son.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontStyle: band.bio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Editar perfil'),
            ),
          ),
        ],
      ),
    );
  }
}
