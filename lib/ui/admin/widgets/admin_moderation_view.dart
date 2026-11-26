import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/admin/widgets/payout_dialog.dart';
import 'package:streamtunes/ui/admin/widgets/admin_section_header.dart';
import 'package:streamtunes/ui/admin/widgets/kiwi_commission_card.dart';
import 'package:streamtunes/ui/admin/widgets/payouts_section.dart';
import 'package:streamtunes/ui/admin/widgets/pending_band_card.dart';
import 'package:streamtunes/ui/admin/widgets/song_report_card.dart';
import 'package:streamtunes/ui/admin/widgets/spend_cap_card.dart';

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
                Expanded(child: Text('Moderación', overflow: TextOverflow.ellipsis)),
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
                    SpendCapCard(
                      active: vm.config.spendCapActive,
                      onChanged: vm.isSavingSpendCap
                          ? null
                          : (val) async {
                              await vm.toggleSpendCap(val);
                              await sessionVM.loadConfig(); // Sincronizar en toda la app
                            },
                    ),
                    const SizedBox(height: 20),

                    // Comisión de KIWI: lo que retiene la app para sostenerse
                    KiwiCommissionCard(
                      pct: vm.kiwiCommissionPct,
                      collected: vm.totalCollected,
                      mercadoPagoFees: vm.totalFees,
                      net: vm.totalNet,
                      kiwiFee: vm.totalKiwiFee,
                      bandShare: vm.totalBandShare,
                    ),
                    const SizedBox(height: 12),

                    // Liquidaciones: lo que KIWI cobró y le debe a cada banda
                    PayoutsSection(viewModel: vm, onPay: _pay, onMarkRefunded: _markRefunded),
                    const SizedBox(height: 20),

                    // 2. Bandas Pendientes de Aprobación (Filtro anti-copyright y calidad)
                    AdminSectionHeader(title: 'BANDAS PENDIENTES DE REVISIÓN', count: vm.pendingBands.length),
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
                      for (final band in vm.pendingBands)
                        PendingBandCard(
                          band: band,
                          onApprove: () => vm.approveBand(band.id),
                          onReject: () => vm.rejectBand(band.id),
                        ),
                    const SizedBox(height: 20),

                    // 3. Reportes Comunitarios de Canciones
                    AdminSectionHeader(title: 'REPORTES COMUNITARIOS ABIERTOS', count: vm.openReports.length),
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
                      for (final report in vm.openReports)
                        SongReportCard(
                          report: report,
                          onDismiss: () => vm.dismissReport(report.id),
                          onHideSong: () => vm.resolveReport(report.id, hideSong: true),
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
}
