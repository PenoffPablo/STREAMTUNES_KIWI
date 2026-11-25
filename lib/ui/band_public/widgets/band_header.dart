import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Encabezado del perfil: portada, género, seguidores, seguir y tienda de merch.
class BandHeader extends StatelessWidget {
  const BandHeader({
    super.key,
    required this.band,
    required this.isFollowing,
    required this.onFollow,
    required this.onOpenLink,
  });

  final Band band;
  final bool isFollowing;
  final ValueChanged<String> onFollow;
  final ValueChanged<String?> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.of(context).currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 100,
                  color: AppTheme.surfaceLight,
                  child: band.coverUrl != null
                      ? Image.network(
                          band.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.groups, size: 48, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.groups, size: 48, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(band.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${band.genre} • ${band.location ?? "Argentina"}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${band.followerCount} seguidores',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (user != null) {
                          onFollow(user.id);
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Inicia sesión para seguir a esta banda.')));
                        }
                      },
                      icon: Icon(isFollowing ? Icons.check : Icons.person_add, size: 16),
                      label: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? AppTheme.surfaceLight : AppTheme.primary,
                        foregroundColor: isFollowing ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (band.bio != null && band.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(band.bio!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (band.merchUrl != null && band.merchUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onOpenLink(band.merchUrl),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: AppTheme.primary),
              label: const Text('Tienda de Merch (Remeras y Vinilos)'),
            ),
          ],
        ],
      ),
    );
  }
}
