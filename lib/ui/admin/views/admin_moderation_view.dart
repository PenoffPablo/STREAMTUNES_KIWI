import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/admin/views/payout_dialog.dart';

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
    _viewModel = DependenciesScope.of(context).createAdminModerationViewModel()
      ..loadModerationData();
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
              description: 'Esta sección es exclusiva para los moderadores y administradores del Colectivo StreamTunes.',
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
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => vm.loadModerationData(),
              ),
            ],
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // 1. Interruptor de Emergencia: Spend Cap
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vm.config.spendCapActive
                            ? AppTheme.accentOrange.withAlpha(50)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vm.config.spendCapActive
                              ? AppTheme.accentOrange
                              : AppTheme.surfaceLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: vm.config.spendCapActive
                                    ? AppTheme.accentOrange
                                    : AppTheme.textSecondary,
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
                                color: vm.config.spendCapActive
                                    ? AppTheme.accentOrange
                                    : AppTheme.textPrimary,
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
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
                      ...vm.pendingBands.map((band) => Card(
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
                                            Text(band.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            Text('${band.genre} • ${band.location ?? "Sin ubicación"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            Text('Slug: /band/${band.slug}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontFamily: 'monospace')),
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
                          )),
                    const SizedBox(height: 20),

                    // 3. Reportes Comunitarios de Canciones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REPORTES COMUNITARIOS ABIERTOS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
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
                      ...vm.openReports.map((report) => Card(
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
                                    Text('Banda: ${report.bandName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
                                        child: const Text('Ocultar Canción'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppTheme.primary : AppTheme.errorRed,
        content: Text(
          ok
              ? 'Pago de \$${data.amount.toStringAsFixed(2)} a ${balance.bandName} registrado. La banda recibe un aviso.'
              : (_viewModel.errorMessage ?? 'No se pudo registrar el pago.'),
          style: TextStyle(color: ok ? Colors.black : Colors.white),
        ),
      ),
    );
  }

  /// KIWI cobra todos los aportes en su cuenta de Mercado Pago. Acá el
  /// moderador ve cuánto le debe a cada banda y registra cada transferencia.
  Widget _buildPayoutsSection(AdminModerationViewModel vm) {
    final withMovement = vm.balances.where((b) => b.netCollected > 0 || b.paid > 0).toList();
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
                  'LIQUIDACIONES A BANDAS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
              Text(
                'KIWI debe \$${vm.totalPending.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Solo cuentan los pagos verificados por Mercado Pago (neto de comisión). '
            'Registrá cada transferencia después de hacerla desde la cuenta de KIWI.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (withMovement.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Todavía no hay aportes verificados.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final b in withMovement)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(b.bandName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Neto \$${b.netCollected.toStringAsFixed(0)} · pagado \$${b.paid.toStringAsFixed(0)}'
                  '${b.lastPayoutAt != null ? ' · último ${b.lastPayoutAt!.day}/${b.lastPayoutAt!.month}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: vm.isPaying(b.bandId)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : b.hasPending
                        ? ElevatedButton(
                            onPressed: () => _pay(b),
                            child: Text('Pagar \$${b.pending.toStringAsFixed(0)}'),
                          )
                        : const Icon(Icons.check_circle, color: AppTheme.primary),
              ),
        ],
      ),
    );
  }
}
