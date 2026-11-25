import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Galería de fotos de shows.
class PhotosCard extends StatelessWidget {
  const PhotosCard({super.key, required this.photos, required this.onAdd});

  final List<BandPhoto> photos;
  final VoidCallback onAdd;

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
                'FOTOS DE SHOWS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.add_a_photo, color: AppTheme.primary),
                onPressed: onAdd,
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
