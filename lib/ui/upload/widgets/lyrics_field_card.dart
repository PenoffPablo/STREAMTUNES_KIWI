import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Letra sincronizada en formato LRC (opcional).
class LyricsFieldCard extends StatelessWidget {
  const LyricsFieldCard({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'LETRA SINCRONIZADA LRC (OPCIONAL)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa el formato estándar [mm:ss.xx] Verso para resaltar las palabras en el reproductor.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  '[00:15.20] El último tren se va perdiendo en la niebla\n[00:22.50] Luces de neón en la estación',
            ),
          ),
        ],
      ),
    );
  }
}
