import 'package:flutter/material.dart';
import 'package:streamtunes/theme/app_theme.dart';

class WaveformPainter extends CustomPainter {
  final List<int> peaks;
  final double progress; // 0.0 a 1.0
  final Color activeColor;
  final Color inactiveColor;

  const WaveformPainter({
    required this.peaks,
    required this.progress,
    this.activeColor = AppTheme.primary,
    this.inactiveColor = AppTheme.textSecondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final barCount = peaks.length;
    final totalSpacing = (barCount - 1) * 2.0;
    final barWidth = ((size.width - totalSpacing) / barCount).clamp(1.0, 10.0);

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final inactivePaint = Paint()
      ..color = inactiveColor.withAlpha(100)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final progressX = size.width * progress;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2.0) + (barWidth / 2);
      final normalizedHeight = (peaks[i] / 100.0) * size.height;
      final yTop = (size.height - normalizedHeight) / 2;
      final yBottom = yTop + normalizedHeight;

      final paint = x <= progressX ? activePaint : inactivePaint;
      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.peaks != peaks;
  }
}

