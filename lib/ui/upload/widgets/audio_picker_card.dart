import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/waveform_painter.dart';
import 'package:streamtunes/ui/upload/view_models/upload_view_model.dart';

/// Selección del audio y progreso del análisis en el worker isolate
/// (SHA-256 y picos de onda), con cancelar y forma de onda al terminar.
class AudioPickerCard extends StatelessWidget {
  const AudioPickerCard({super.key, required this.viewModel});

  final UploadViewModel viewModel;

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
              Icon(Icons.audiotrack, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'ARCHIVO DE AUDIO (.MP3, .WAV, .M4A)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tamaño máximo: 50 MB. Se verificará firma SHA-256 y picos de onda en un Isolate pesado.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),

          if (viewModel.isAnalyzing) ...[
            // Progreso real reportado por el isolate worker vía SendPort.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${viewModel.analysisStage}... ${(viewModel.analysisProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                  ),
                ),
                TextButton(onPressed: viewModel.cancelAnalysis, child: const Text('Cancelar')),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: viewModel.analysisProgress,
              minHeight: 4,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ] else if (viewModel.analysisResult != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${viewModel.selectedAudio?.name} (${viewModel.analysisResult!.format.toUpperCase()} • ${(viewModel.analysisResult!.byteLength / (1024 * 1024)).toStringAsFixed(1)} MB)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                TextButton(onPressed: () => viewModel.pickAndAnalyzeAudio(), child: const Text('Cambiar')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: WaveformPainter(peaks: viewModel.analysisResult!.waveformPeaks, progress: 1.0),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => viewModel.pickAndAnalyzeAudio(),
              icon: const Icon(Icons.file_upload_outlined, color: AppTheme.primary),
              label: const Text('Seleccionar archivo de audio'),
            ),
          ],
        ],
      ),
    );
  }
}
