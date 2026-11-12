import 'package:flutter/material.dart';
import 'package:streamtunes/theme/app_theme.dart';

class SpendCapBanner extends StatelessWidget {
  const SpendCapBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.accentOrange.withAlpha(50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: AppTheme.accentOrange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estamos con mucha demanda, aguanten un toque: subidas temporalmente pausadas para cuidar el presupuesto del colectivo.',
              style: TextStyle(
                color: Colors.orange.shade200,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

