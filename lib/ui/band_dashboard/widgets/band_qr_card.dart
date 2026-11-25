import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// QR de la banda para recitales: se genera sin conexión a partir del slug.
class BandQrCard extends StatelessWidget {
  const BandQrCard({super.key, required this.band});

  final Band band;

  @override
  Widget build(BuildContext context) {
    final qrData = 'https://streamtunes.app/band/${band.slug}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CÓDIGO QR INTELIGENTE (RECITALES & SÓTANOS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Escaneo universal: si el fan tiene instalada StreamTunes abre la app y te sigue al instante. Si no la tiene instalada, lo lleva directo a descargarla.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: qrData, version: QrVersions.auto, size: 160.0, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            qrData,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
