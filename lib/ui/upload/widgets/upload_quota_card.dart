import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/upload/view_models/upload_view_model.dart';

/// Cupos de la banda: temas (máx. 20) y álbumes/EPs (máx. 2).
class UploadQuotaCard extends StatelessWidget {
  const UploadQuotaCard({super.key, required this.viewModel});

  final UploadViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: viewModel.hasReachedSongLimit ? AppTheme.errorRed : AppTheme.surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('CUPO DE CANCIONES', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${viewModel.songCount} / ${viewModel.maxSongs}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.hasReachedSongLimit ? AppTheme.errorRed : AppTheme.primary,
                ),
              ),
            ],
          ),
          Container(height: 30, width: 1, color: AppTheme.surfaceLight),
          Column(
            children: [
              const Text('CUPO DE ÁLBUMES/EPS', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${viewModel.albumCount} / ${viewModel.maxAlbums}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: viewModel.hasReachedAlbumLimit ? AppTheme.accentOrange : AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
