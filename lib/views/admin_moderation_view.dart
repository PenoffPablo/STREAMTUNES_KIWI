import 'package:flutter/material.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';

class AdminModerationView extends StatefulWidget {
  const AdminModerationView({super.key});

  @override
  State<AdminModerationView> createState() => _AdminModerationViewState();
}

class _AdminModerationViewState extends State<AdminModerationView> {
  AdminModerationViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel == null) {
      final repos = RepositoriesScope.of(context);
      _viewModel = AdminModerationViewModel(
        moderationRepo: repos.moderationRepository,
        configRepo: repos.configRepository,
      );
      _viewModel!.loadModerationData();
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    final vm = _viewModel!;

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
}
