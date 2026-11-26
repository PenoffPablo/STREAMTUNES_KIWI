import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Título de una sección del panel con la cantidad de elementos.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
      ],
    );
  }
}
