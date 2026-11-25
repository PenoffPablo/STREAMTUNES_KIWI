import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Estado de cuenta con KIWI: lo que le corresponde a la banda (neto menos la
/// comisión de KIWI), lo ya cobrado y lo que
/// falta cobrar, más los últimos pagos que KIWI le hizo a la banda.
class KiwiAccountCard extends StatelessWidget {
  const KiwiAccountCard({
    super.key,
    required this.balance,
    required this.payouts,
    this.commissionPct = kDefaultKiwiCommissionPct,
  });

  final BandBalance balance;
  final List<BandPayout> payouts;

  /// Comisión de KIWI sobre el neto (ya descontada en el saldo).
  final int commissionPct;

  @override
  Widget build(BuildContext context) {
    final b = balance;
    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'TUS APORTES CON KIWI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Te corresponde', _money(b.bandShare)),
              stat('Ya cobrado', _money(b.paid)),
              stat('A cobrar', _money(b.pending), color: b.hasPending ? AppTheme.primary : null),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los fans pagan con Mercado Pago a la cuenta de KIWI. De lo recaudado '
            '(${_money(b.collected)}) se descuenta la comisión de Mercado Pago '
            '(${_money(b.mercadoPagoFees)}) y el $commissionPct% de KIWI (${_money(b.kiwiFee)}), '
            'que sostiene la app: servidores, almacenamiento y la operación.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          if (payouts.isNotEmpty) ...[
            const Divider(color: AppTheme.surfaceLight, height: 20),
            const Text('Últimos pagos de KIWI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            for (final p in payouts.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_date(p.paidAt)}${p.reference != null ? ' · Op. ${p.reference}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(_money(p.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _money(double v) => '\$${v.toStringAsFixed(0)}';
String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
