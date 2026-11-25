import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Galería horizontal de fotos de shows (no se muestra si no hay fotos).
class PhotosGallery extends StatelessWidget {
  const PhotosGallery({super.key, required this.photos});

  final List<BandPhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GALERÍA DE SHOWS',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final photo = photos[idx];
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 160,
                  color: AppTheme.surfaceLight,
                  child: Image.network(
                    photo.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.camera_alt, color: AppTheme.textSecondary)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
