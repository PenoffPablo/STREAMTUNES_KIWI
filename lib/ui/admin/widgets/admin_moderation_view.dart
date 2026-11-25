import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/admin/widgets/payout_dialog.dart';

class AdminModerationView extends StatefulWidget {
  const AdminModerationView({super.key});

  @override
  State<AdminModerationView> createState() => _AdminModerationViewState();
}

class _AdminModerationViewState extends State<AdminModerationView> {
  late final AdminModerationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createAdminModerationViewModel()..init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _viewModel;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final sessionVM = SessionScope.of(context);
        final user = sessionVM.currentUser;

        if (user == null || !user.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Moderación')),
            body: const EmptyStateView(
              icon: Icons.shield_outlined,
              title: 'Acceso Denegado',
              description:
                  'Esta sección es exclusiva para los moderadores y administradores del Colectivo StreamTunes.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.shield, color: AppTheme.primary, size: 22),
                SizedBox(width: 8),
                Text('Panel de Moderación del Colectivo'),
              ],
            ),
            actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => vm.loadModerationData())],
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    if (vm.errorMessage != null) ...[
                      ErrorBanner(message: vm.errorMessage!, onRetry: vm.loadModerationData),
                      const SizedBox(height: 12),
                    ],
                    // 1. Interruptor de Emergencia: Spend Cap
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vm.config.spendCapActive ? AppTheme.accentOrange.withAlpha(50) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vm.config.spendCapActive ? AppTheme.accentOrange : AppTheme.surfaceLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: vm.config.spendCapActive ? AppTheme.accentOrange : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'FRENO DE EMERGENCIA (SPEND CAP)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Si una banda se viraliza y los costos de Supabase Storage se disparan, activa este interruptor para bloquear temporalmente nuevas subidas y streaming pesado.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              vm.config.spendCapActive
                                  ? 'FRENO ACTIVO (Tráfico bloqueado)'
                                  : 'Freno inactivo (Operación normal)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: vm.config.spendCapActive ? AppTheme.accentOrange : AppTheme.textPrimary,
                              ),
                            ),
                            value: vm.config.spendCapActive,
                            activeThumbColor: AppTheme.accentOrange,
                            onChanged: (val) async {
                              await vm.toggleSpendCap(val);
                              sessionVM.loadConfig(); // Sincronizar en toda la app
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Liquidaciones: lo que KIWI cobró y le debe a cada banda
                    _buildPayoutsSection(vm),
                    const SizedBox(height: 20),

                    // 2. Bandas Pendientes de Aprobación (Filtro anti-copyright y calidad)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BANDAS PENDIENTES DE REVISIÓN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${vm.pendingBands.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (vm.pendingBands.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No hay bandas pendientes en la lista de espera.',
                              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      )
                    else
                      ...vm.pendingBands.map(
                        (band) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        color: AppTheme.surfaceLight,
                                        child: band.coverUrl != null
                                            ? Image.network(
                                                band.coverUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.groups),
                                              )
                                            : const Icon(Icons.groups),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            band.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${band.genre} • ${band.location ?? "Sin ubicación"}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            'Slug: /band/${band.slug}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primary,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (band.bio != null) ...[
                                  const SizedBox(height: 8),
                                  Text(band.bio!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => vm.rejectBand(band.id),
                                      child: const Text('Rechazar', style: TextStyle(color: AppTheme.errorRed)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => vm.approveBand(band.id),
                                      child: const Text('Aprobar Banda'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // 3. Reportes Comunitarios de Canciones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REPORTES COMUNITARIOS ABIERTOS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${vm.openReports.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (vm.openReports.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No hay reportes de copyright ni abusos pendientes.',
                              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      )
                    else
                      ...vm.openReports.map(
                        (report) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.report_problem, color: AppTheme.accentOrange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Canción: "${report.songTitle ?? report.songId}"',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (report.bandName != null)
                                  Text(
                                    'Banda: ${report.bandName}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Motivo: "${report.reason}"',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => vm.dismissReport(report.id),
                                      child: const Text('Desestimar'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => vm.resolveReport(report.id, hideSong: true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorRed,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Ocultar Canción'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _pay(BandBalance balance) async {
    final data = await PayoutDialog.show(context, balance);
    if (data == null || !mounted) return;
    final ok = await _viewModel.registerPayout(
      bandId: balance.bandId,
      amount: data.amount,
      reference: data.reference,
      note: data.note,
    );
    if (!mounted) return;
    if (!ok) {
      showErrorSnackBar(
        context,
        title: 'No se registró el pago a ${balance.bandName}',
        message: _viewModel.payoutError ?? kUnexpectedErrorMessage,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text(
          'Pago de \$${data.amount.toStringAsFixed(2)} a ${balance.bandName} registrado. La banda recibe un aviso.',
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  Future<void> _markRefunded(RejectedPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Ya devolviste este pago?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Confirmá solo si ya hiciste la devolución de ${_money(payment.amount)} '
          '(pago ${payment.mpPaymentId}) desde Mercado Pago.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, lo devolví')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _viewModel.markRefunded(payment.id);
    if (!mounted || ok) return;
    showErrorSnackBar(
      context,
      title: 'No se pudo marcar la devolución',
      message: _viewModel.payoutError ?? kUnexpectedErrorMessage,
    );
  }

  static String _money(double v) => v == v.roundToDouble() ? '\$${v.toStringAsFixed(0)}' : '\$${v.toStringAsFixed(2)}';

  static String _dateTime(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.day}/${l.month} ${two(l.hour)}:${two(l.minute)}';
  }

  /// KIWI cobra todos los aportes en su cuenta de Mercado Pago. Acá el
  /// moderador ve cuánto entró, cuánto le debe a cada banda y registra cada
  /// transferencia. Se actualiza solo cuando entra un pago (realtime).
  Widget _buildPayoutsSection(AdminModerationViewModel vm) {
    final bandsWithMovement = vm.balances.where((b) => b.collected > 0 || b.paid > 0).toList();

    Widget total(String label, double value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(
            _money(value),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
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
              IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh, size: 20), onPressed: vm.refreshMoney),
            ],
          ),

          if (vm.moneyError != null) ...[
            ErrorBanner(warning: true, message: vm.moneyError!, onRetry: vm.refreshMoney),
            const SizedBox(height: 8),
          ],

          // Resumen general
          Row(
            children: [
              total('Recaudado', vm.totalCollected),
              total('Comisión MP', vm.totalFees),
              total('Ya liquidado', vm.totalPaid),
              total('KIWI debe', vm.totalPending, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Solo cuentan pagos verificados por Mercado Pago. Lo que KIWI debe es el neto '
            '(descontada la comisión) menos lo ya liquidado.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),

          // Pagos cobrados que no se pudieron registrar: hay que devolverlos.
          if (vm.pendingRefunds.isNotEmpty) ...[
            sectionTitle('PAGOS A DEVOLVER (${_money(vm.totalToRefund)})'),
            const Text(
              'Mercado Pago los cobró pero no se pudieron registrar como aporte. Devolvé cada uno '
              'desde Mercado Pago (Actividad → el pago → Devolver) y después marcalo acá.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            for (final r in vm.pendingRefunds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.undo, color: AppTheme.accentOrange),
                title: Text(
                  '${_money(r.amount)} · ${r.bandName ?? 'Sin banda'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${r.reason}\nPago MP ${r.mpPaymentId} · ${_dateTime(r.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                isThreeLine: true,
                trailing: vm.isRefunding(r.id)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentOrange),
                      )
                    : TextButton(onPressed: () => _markRefunded(r), child: const Text('Ya lo devolví')),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(b.bandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  'Recaudó ${_money(b.collected)} · neto ${_money(b.netCollected)} · '
                  'liquidado ${_money(b.paid)}'
                  '${b.lastPayoutAt != null ? ' (último ${b.lastPayoutAt!.toLocal().day}/${b.lastPayoutAt!.toLocal().month})' : ''}\n'
                  'KIWI le debe: ${_money(b.pending)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                isThreeLine: true,
                trailing: vm.isPaying(b.bandId)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : b.hasPending
                    ? ElevatedButton(onPressed: () => _pay(b), child: Text('Pagar ${_money(b.pending)}'))
                    : const Icon(Icons.check_circle, color: AppTheme.primary),
              ),

          // Pagos recibidos
          sectionTitle('ÚLTIMOS PAGOS RECIBIDOS'),
          if (vm.recentPayments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Todavía no entraron pagos.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final d in vm.recentPayments)
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money(d.amountArs), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'neto ${_money(d.netOrAmount)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
