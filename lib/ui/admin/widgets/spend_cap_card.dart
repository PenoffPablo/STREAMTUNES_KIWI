import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Freno de emergencia: bloquea subidas y streaming pesado si se disparan los costos.
class SpendCapCard extends StatelessWidget {
  const SpendCapCard({super.key, required this.active, required this.onChanged});

  final bool active;
  /// `null` mientras se guarda: el interruptor queda deshabilitado.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? AppTheme.accentOrange.withAlpha(50) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppTheme.accentOrange : AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: active ? AppTheme.accentOrange : AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FRENO DE EMERGENCIA (SPEND CAP)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Si una banda se viraliza y los costos de Supabase Storage se disparan, activa este interruptor para bloquear temporalmente nuevas subidas y streaming pesado.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          // Material propio: el efecto al tocar se pinta sobre el fondo de la tarjeta.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                active ? 'FRENO ACTIVO (Tráfico bloqueado)' : 'Freno inactivo (Operación normal)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: active ? AppTheme.accentOrange : AppTheme.textPrimary,
                ),
              ),
              value: active,
              activeThumbColor: AppTheme.accentOrange,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
