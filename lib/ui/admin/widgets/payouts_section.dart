import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';

/// KIWI cobra todos los aportes en su cuenta de Mercado Pago. Acá el
/// moderador ve cuánto entró, cuánto le debe a cada banda y registra cada
/// transferencia. Se actualiza solo cuando entra un pago (realtime).
class PayoutsSection extends StatelessWidget {
  const PayoutsSection({super.key, required this.viewModel, required this.onPay, required this.onMarkRefunded});

  final AdminModerationViewModel viewModel;
  final ValueChanged<BandBalance> onPay;
  final ValueChanged<RejectedPayment> onMarkRefunded;

  @override
  Widget build(BuildContext context) {
    final bandsWithMovement = viewModel.balances.where((b) => b.collected > 0 || b.paid > 0).toList();

    Widget total(String label, double value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 2, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppTheme.textSecondary,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'APORTES Y LIQUIDACIONES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: viewModel.refreshMoney,
              ),
            ],
          ),

          if (viewModel.moneyError != null) ...[
            ErrorBanner(warning: true, message: viewModel.moneyError!, onRetry: viewModel.refreshMoney),
            const SizedBox(height: 8),
          ],

          // Resumen general
          Row(
            children: [
              total('Recaudado', viewModel.totalCollected),
              total('Comisión KIWI', viewModel.totalKiwiFee, color: AppTheme.accentOrange),
              total('Ya liquidado', viewModel.totalPaid),
              total('A liquidar', viewModel.totalPending, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Solo cuentan pagos verificados por Mercado Pago. A cada banda le corresponde el neto '
            '(descontada la comisión de MP) menos la comisión de KIWI, '
            'menos lo ya liquidado.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),

          // Pagos cobrados que no se pudieron registrar: hay que devolverlos.
          if (viewModel.pendingRefunds.isNotEmpty) ...[
            sectionTitle('PAGOS A DEVOLVER (${_money(viewModel.totalToRefund)})'),
            const Text(
              'Mercado Pago los cobró pero no se pudieron registrar como aporte. Devolvé cada uno '
              'desde Mercado Pago (Actividad → el pago → Devolver) y después marcalo acá.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            for (final r in viewModel.pendingRefunds)
              _MoneyRow(
                icon: const Icon(Icons.undo, color: AppTheme.accentOrange, size: 20),
                title: '${_money(r.amount)} · ${r.bandName ?? 'Sin banda'}',
                subtitle: '${r.reason}\nPago MP ${r.mpPaymentId} · ${_dateTime(r.createdAt)}',
                action: viewModel.isRefunding(r.id)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentOrange),
                      )
                    : TextButton(onPressed: () => onMarkRefunded(r), child: const Text('Ya lo devolví')),
              ),
          ],

          // Saldo por banda
          sectionTitle('SALDO POR BANDA'),
          if (bandsWithMovement.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Todavía no hay aportes verificados.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final b in bandsWithMovement)
              _MoneyRow(
                title: b.bandName,
                subtitle:
                    ('Recaudó ${_money(b.collected)} · neto ${_money(b.netCollected)} · '
                    'KIWI ${_money(b.kiwiFee)} · liquidado ${_money(b.paid)}'
                    '${b.lastPayoutAt != null ? ' (último ${b.lastPayoutAt!.toLocal().day}/${b.lastPayoutAt!.toLocal().month})' : ''}\n'
                    'Le corresponde: ${_money(b.pending)}'),
                action: viewModel.isPaying(b.bandId)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : b.hasPending
                    ? ElevatedButton(onPressed: () => onPay(b), child: Text('Pagar ${_money(b.pending)}'))
                    : const Icon(Icons.check_circle, color: AppTheme.primary),
              ),

          // Pagos recibidos
          sectionTitle('ÚLTIMOS PAGOS RECIBIDOS'),
          if (viewModel.recentPayments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Todavía no entraron pagos.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final d in viewModel.recentPayments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${d.bandName ?? 'Banda'} · ${d.donorName}\n${_dateTime(d.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_money(d.amountArs), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'neto ${_money(d.netOrAmount)}\nbanda ${_money(d.bandShare)}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Fila de la sección de dinero: texto arriba y la acción (pagar, devolver)
/// debajo, alineada a la derecha. A diferencia de un ListTile, un botón con
/// un monto largo nunca se queda sin lugar.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.title, required this.subtitle, required this.action, this.icon});

  final String title;
  final String subtitle;
  final Widget action;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 2), child: icon), const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double v) => v == v.roundToDouble() ? '\$${v.toStringAsFixed(0)}' : '\$${v.toStringAsFixed(2)}';

String _dateTime(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.day}/${l.month} ${two(l.hour)}:${two(l.minute)}';
}
