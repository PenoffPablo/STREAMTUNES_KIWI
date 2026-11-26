import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_overview.dart';
import 'package:streamtunes/ui/admin/view_models/admin_bands_view_model.dart';
import 'package:streamtunes/ui/admin/widgets/band_overview_card.dart';
import 'package:streamtunes/ui/band_public/widgets/band_public_view.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Panel "Bandas del colectivo": todas las bandas con filtros (estado,
/// género, búsqueda y orden) y las acciones de moderación.
class AdminBandsView extends StatefulWidget {
  const AdminBandsView({super.key});

  @override
  State<AdminBandsView> createState() => _AdminBandsViewState();
}

class _AdminBandsViewState extends State<AdminBandsView> {
  late final AdminBandsViewModel _viewModel;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = DependenciesScope.of(context).createAdminBandsViewModel()..load();
  }

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(BandOverview overview, BandStatus status) async {
    final band = overview.band;
    if (status == BandStatus.suspended) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(band.isPending ? '¿Rechazar ${band.name}?' : '¿Suspender ${band.name}?'),
          content: const Text(
            'La banda deja de verse en el inicio y sus temas dejan de ser públicos. '
            'No se borra nada: la podés reactivar cuando quieras.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(band.isPending ? 'Rechazar' : 'Suspender'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final ok = await _viewModel.setBandStatus(band.id, status);
    if (!mounted) return;
    if (!ok) {
      showErrorSnackBar(
        context,
        title: 'No se pudo cambiar el estado de ${band.name}',
        message: _viewModel.actionError ?? kUnexpectedErrorMessage,
      );
      return;
    }
    final (_, label, _) = bandStatusStyle(status);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${band.name}: $label.')));
  }

  void _clearFilters() {
    _search.clear();
    _viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandas del colectivo', overflow: TextOverflow.ellipsis),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _viewModel.load)],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final vm = _viewModel;
          if (vm.isLoading && vm.totalCount == 0) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final bands = vm.bands;
          return RefreshIndicator(
            onRefresh: vm.load,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (vm.errorMessage != null) ...[
                  ErrorBanner(message: vm.errorMessage!, onRetry: vm.load),
                  const SizedBox(height: 12),
                ],
                _StatusFilter(viewModel: vm),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: vm.setQuery,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por nombre, ciudad o creador',
                    isDense: true,
                    suffixIcon: vm.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              vm.setQuery('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: vm.genreFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Género', isDense: true),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                          for (final g in vm.genres) DropdownMenuItem<String?>(value: g, child: Text(g)),
                        ],
                        onChanged: vm.setGenreFilter,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<BandSort>(
                        initialValue: vm.sort,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Ordenar', isDense: true),
                        items: [
                          for (final s in BandSort.values)
                            DropdownMenuItem(value: s, child: Text(s.label, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (s) => s == null ? null : vm.setSort(s),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${bands.length} de ${vm.totalCount} bandas',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    if (vm.hasActiveFilters) TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                  ],
                ),
                if (bands.isEmpty && vm.errorMessage == null)
                  EmptyStateView(
                    icon: Icons.search_off,
                    title: vm.totalCount == 0 ? 'Todavía no hay bandas' : 'Ninguna banda coincide',
                    description: vm.totalCount == 0
                        ? 'Cuando alguien registre su banda va a aparecer acá.'
                        : 'Probá con otro filtro o limpiá la búsqueda.',
                  )
                else
                  for (final o in bands)
                    BandOverviewCard(
                      key: ValueKey(o.band.id),
                      overview: o,
                      busy: vm.isBusy(o.band.id),
                      onSetStatus: (status) => _changeStatus(o, status),
                      onOpenProfile: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => BandPublicView(bandId: o.band.id)),
                      ),
                    ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Filtro por estado con la cantidad de bandas de cada uno.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.viewModel});

  final AdminBandsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    Widget chip(BandStatus? status, String label, int count, Color color) => ChoiceChip(
          label: Text('$label ($count)'),
          selected: vm.statusFilter == status,
          selectedColor: color.withAlpha(60),
          side: BorderSide(color: color.withAlpha(120)),
          onSelected: (_) => vm.setStatusFilter(status),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(null, 'Todas', vm.totalCount, AppTheme.textSecondary),
        for (final s in BandStatus.values)
          chip(
            s,
            switch (s) {
              BandStatus.approved => 'Aprobadas',
              BandStatus.pending => 'Pendientes',
              BandStatus.suspended => 'Suspendidas',
            },
            vm.countFor(s),
            bandStatusStyle(s).$1,
          ),
      ],
    );
  }
}
