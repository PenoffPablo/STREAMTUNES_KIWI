import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Comisión de KIWI: el porcentaje del neto de cada aporte que se queda la app
/// para sostenerse. Muestra el total retenido y de dónde sale, para que el
/// dato no se pierda entre los saldos de las bandas.
class KiwiCommissionCard extends StatelessWidget {
  const KiwiCommissionCard({
    super.key,
    required this.pct,
    required this.collected,
    required this.mercadoPagoFees,
    required this.net,
    required this.kiwiFee,
    required this.bandShare,
  });

  final int pct;
  final double collected;
  final double mercadoPagoFees;
  final double net;
  final double kiwiFee;
  final double bandShare;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: bold ? null : AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentOrange.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism_outlined, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'COMISIÓN KIWI · $pct%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _money(kiwiFee),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.accentOrange),
          ),
          const Text(
            'retenido para sostener la app',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            'El $pct% de cada aporte (sobre lo que queda después de Mercado Pago) es para '
            'sostener StreamTunes: servidores, almacenamiento y la operación. No es ganancia '
            'del equipo. Ya está descontado de lo que se le debe a cada banda. Cada aporte '
            'guarda la comisión con la que entró: si el porcentaje cambia, lo anterior no se recalcula.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const Divider(color: AppTheme.surfaceLight, height: 20),
          line('Aportes de los fans', _money(collected)),
          line('− Comisión de Mercado Pago', _money(mercadoPagoFees)),
          line('= Neto recibido', _money(net)),
          line('− Comisión KIWI', _money(kiwiFee), color: AppTheme.accentOrange),
          line('= Para las bandas', _money(bandShare), bold: true, color: AppTheme.primary),
        ],
      ),
    );
  }
}

String _money(double v) => v == v.roundToDouble() ? '\$${v.toStringAsFixed(0)}' : '\$${v.toStringAsFixed(2)}';
