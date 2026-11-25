import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Aviso que aparece arriba del perfil cuando entra un aporte en vivo.
class LiveDonationToast extends StatelessWidget {
  final Donation donation;
  final VoidCallback onDismiss;

  const LiveDonationToast({super.key, required this.donation, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.black, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¡NUEVO APORTE EN VIVO!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${donation.isAnonymous ? "Fan anónimo" : donation.donorName} aportó \$${donation.amountArs.toInt()} ARS',
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
