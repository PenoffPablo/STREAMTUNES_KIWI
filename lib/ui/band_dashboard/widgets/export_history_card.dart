import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Botón para exportar el historial (CSV firmado en otro isolate). Máx. 1 por día.
class ExportHistoryCard extends StatelessWidget {
  const ExportHistoryCard({super.key, required this.canExportToday, required this.isExporting, required this.onExport});

  final bool canExportToday;
  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.file_download_outlined, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              canExportToday
                  ? 'Exportar historial de reproducciones (CSV firmado)'
                  : 'Reporte de hoy ya generado. Disponible de nuevo en 24 h.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          isExporting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                )
              : TextButton(onPressed: canExportToday ? onExport : null, child: const Text('Exportar')),
        ],
      ),
    );
  }
}
