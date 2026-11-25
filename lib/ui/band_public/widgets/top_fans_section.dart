import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Ranking de los 10 fans que más escucharon (los perfiles privados, anónimos).
class TopFansSection extends StatelessWidget {
  const TopFansSection({super.key, required this.fans});

  final List<TopFanStat> fans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOP 10 FANS EN VIVO (ÚLTIMOS 30 DÍAS)',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (fans.isEmpty)
          const Text(
            'Aún no hay reproducciones suficientes para el ranking.',
            style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: fans.map((fan) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          '#${fan.rank}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: fan.rank <= 3 ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.surfaceLight,
                        backgroundImage: fan.isPublic && fan.avatarUrl != null ? NetworkImage(fan.avatarUrl!) : null,
                        onBackgroundImageError: fan.isPublic && fan.avatarUrl != null
                            ? (exception, stackTrace) {}
                            : null,
                        child: !fan.isPublic || fan.avatarUrl == null
                            ? const Icon(Icons.person, size: 16, color: AppTheme.textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fan.isPublic ? fan.displayName : 'Fan anónimo (Privado)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: fan.isPublic ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontStyle: fan.isPublic ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ),
                      Text(
                        '${fan.minutesListened} min',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
