import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/config/dependencies.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/admin/view_models/admin_bands_view_model.dart';
import 'package:streamtunes/ui/admin/widgets/admin_bands_view.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

void main() {
  late FakeModerationRepository repo;
  late AdminBandsViewModel vm;

  setUp(() async {
    repo = FakeModerationRepository();
    vm = AdminBandsViewModel(moderationRepo: repo);
    await vm.load();
  });

  tearDown(() => vm.dispose());

  test('carga todas las bandas y cuenta cada estado', () {
    expect(vm.totalCount, 3);
    expect(vm.countFor(BandStatus.approved), 1);
    expect(vm.countFor(BandStatus.pending), 1);
    expect(vm.countFor(BandStatus.suspended), 1);
    expect(vm.genres, ['Cumbia', 'Indie', 'Rock']);
  });

  test('filtra por estado, género y texto (sin importar tildes)', () {
    vm.setStatusFilter(BandStatus.pending);
    expect(vm.bands.map((o) => o.band.name), ['Nebulosa Subterránea']);

    vm.setStatusFilter(null);
    vm.setGenreFilter('Rock');
    expect(vm.bands.map((o) => o.band.name), ['Los Fuzzers']);

    vm.setGenreFilter(null);
    vm.setQuery('subterranea'); // sin tilde encuentra "Subterránea"
    expect(vm.bands.single.band.name, 'Nebulosa Subterránea');

    vm.setQuery('lanús'); // busca también por ciudad
    expect(vm.bands.single.band.name, 'Cumbia del Conurbano');

    expect(vm.hasActiveFilters, isTrue);
    vm.clearFilters();
    expect(vm.bands, hasLength(3));
  });

  test('ordena por nombre y por seguidores', () {
    vm.setSort(BandSort.name);
    expect(vm.bands.map((o) => o.band.name), ['Cumbia del Conurbano', 'Los Fuzzers', 'Nebulosa Subterránea']);
    vm.setSort(BandSort.followers);
    expect(vm.bands.first.band.name, 'Los Fuzzers');
  });

  test('aprobar una pendiente la pasa a aprobada (y los contadores se actualizan)', () async {
    final pending = vm.bands.firstWhere((o) => o.band.isPending).band;
    expect(await vm.setBandStatus(pending.id, BandStatus.approved), isTrue);

    expect(vm.countFor(BandStatus.pending), 0);
    expect(vm.countFor(BandStatus.approved), 2);
    expect(vm.isBusy(pending.id), isFalse);
    // Se guardó en el repositorio, no solo en pantalla.
    expect((await repo.getAllBands()).firstWhere((o) => o.band.id == pending.id).band.isApproved, isTrue);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('el panel de bandas entra en un celular de ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(DependenciesScope(
        dependencies: AppDependencies.fake(moderationRepository: FakeModerationRepository()),
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AdminBandsView()),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Todas (3)'), findsOneWidget);
      expect(find.text('Nebulosa Subterránea'), findsOneWidget, reason: 'la más reciente va primero');

      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      for (var i = 0; i < 3; i++) {
        list.position.jumpTo(list.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.text('Los Fuzzers'), findsOneWidget, reason: 'la más vieja queda al final');
      expect(tester.takeException(), isNull);
    });
  }
}
