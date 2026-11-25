import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/report.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Reporte de la comunidad sobre una canción: desestimar u ocultar el tema.
class SongReportCard extends StatelessWidget {
  const SongReportCard({super.key, required this.report, required this.onDismiss, required this.onHideSong});

  final SongReport report;
  final VoidCallback onDismiss;
  final VoidCallback onHideSong;

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
                const Icon(Icons.report_problem, color: AppTheme.accentOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canción: "${report.songTitle ?? report.songId}"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (report.bandName != null)
              Text('Banda: ${report.bandName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Motivo: "${report.reason}"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => onDismiss(), child: const Text('Desestimar')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onHideSong(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
                  child: const Text('Ocultar Canción'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
