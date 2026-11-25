import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/upload/view_models/upload_view_model.dart';

/// Portada del tema: cámara (si el dispositivo tiene) o galería.
class CoverPickerCard extends StatelessWidget {
  const CoverPickerCard({super.key, required this.viewModel});

  final UploadViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PORTADA DEL TEMA',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.surfaceLight,
                  child: viewModel.selectedCoverPath != null && !kIsWeb
                      ? Image.file(File(viewModel.selectedCoverPath!), fit: BoxFit.cover)
                      : const Icon(Icons.image, size: 40, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (viewModel.hasCamera) ...[
                      ElevatedButton.icon(
                        onPressed: () => viewModel.pickCoverPhoto(fromCamera: true),
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const Text('Tomar con cámara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => viewModel.pickCoverPhoto(fromCamera: false),
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Elegir de galería'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
