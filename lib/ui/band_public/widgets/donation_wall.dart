import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Muro de aportes: se actualiza en vivo (Supabase Realtime).
class DonationWall extends StatelessWidget {
  const DonationWall({super.key, required this.donations});

  final List<Donation> donations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MURO DE APORTES EN VIVO (REALTIME)',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (donations.isEmpty)
          const Text(
            'Sé el primer fan en apoyar a la banda en su meta.',
            style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
          )
        else
          ...donations.map(
            (d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                d.isAnonymous ? 'Fan anónimo' : d.donorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+\$${d.amountArs.toInt()} ARS',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (d.message != null && d.message!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"${d.message!}"',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
