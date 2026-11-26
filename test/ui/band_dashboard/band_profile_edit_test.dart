import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/band_dashboard/widgets/edit_band_profile_view.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

class _CountingBands extends FakeBandsRepository {
  final uploads = <String>[];

  @override
  Future<String> uploadBandCover(String bandId, String localPath) async {
    uploads.add(localPath);
    return 'https://cdn.example.com/$bandId/cover.jpg';
  }
}

void main() {
  late _CountingBands bands;
  late BandDashboardViewModel vm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    bands = _CountingBands();
    vm = BandDashboardViewModel(
      bandsRepo: bands,
      songsRepo: FakeSongsRepository(),
      bandId: _bandId,
      prefs: await SharedPreferences.getInstance(),
    );
    await vm.loadDashboard();
  });

  tearDown(() => vm.dispose());

  test('guarda nombre, género, ciudad, bio, meta, redes y foto nueva', () async {
    final slugBefore = vm.band!.slug;
    final ok = await vm.updateProfile(
      name: ' Los Fuzzers Eléctricos ',
      genre: 'Punk',
      location: 'Rosario',
      bio: 'Garage y fuzz desde 2019.',
      donationGoal: 80000,
      socialLinks: {'instagram': 'instagram.com/losfuzzers', 'spotify': '', 'youtube': 'https://youtube.com/@fuzz'},
      merchUrl: 'tienda.losfuzzers.com',
      newCoverPath: '/tmp/foto.jpg',
    );

    expect(ok, isTrue, reason: vm.profileError);
    final band = vm.band!;
    expect(band.name, 'Los Fuzzers Eléctricos');
    expect(band.genre, 'Punk');
    expect(band.location, 'Rosario');
    expect(band.bio, 'Garage y fuzz desde 2019.');
    expect(band.donationGoal, 80000);
    expect(band.socialLinks['instagram'], 'https://instagram.com/losfuzzers', reason: 'se completa el https://');
    expect(band.socialLinks.containsKey('spotify'), isFalse, reason: 'un link vacío se borra');
    expect(band.merchUrl, 'https://tienda.losfuzzers.com');
    expect(band.coverUrl, 'https://cdn.example.com/$_bandId/cover.jpg');
    expect(bands.uploads, ['/tmp/foto.jpg']);
    expect(band.slug, slugBefore, reason: 'el QR impreso sigue funcionando');
    expect(band.status, BandStatus.approved, reason: 'editar el perfil no toca la aprobación');
  });

  test('borrar la ciudad o la bio las deja vacías (no conserva las anteriores)', () async {
    await vm.updateProfile(name: 'Los Fuzzers', genre: 'Rock', location: 'Rosario', bio: 'Algo', donationGoal: 1000);
    final ok = await vm.updateProfile(name: 'Los Fuzzers', genre: 'Rock', location: '', bio: '  ', donationGoal: 1000);

    expect(ok, isTrue);
    expect(vm.band!.location, isNull);
    expect(vm.band!.bio, isNull);
  });

  test('datos inválidos no se guardan y explican el motivo', () async {
    final before = vm.band!;

    expect(await vm.updateProfile(name: ' ', genre: 'Rock', donationGoal: 0), isFalse);
    expect(vm.profileError, contains('nombre'));

    expect(
      await vm.updateProfile(name: 'Los Fuzzers', genre: 'Rock', donationGoal: 0, socialLinks: {'instagram': 'no es un link'}),
      isFalse,
    );
    expect(vm.profileError, contains('Instagram'));

    expect(await vm.updateProfile(name: 'Los Fuzzers', genre: 'Rock', donationGoal: -5), isFalse);
    expect(vm.profileError, contains('meta'));

    expect(vm.band!.name, before.name, reason: 'nada cambió');
    expect(bands.uploads, isEmpty);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('el formulario de edición entra en un celular de ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: EditBandProfileView(viewModel: vm)));
      await tester.pumpAndSettle();
      expect(find.text('Nombre de la banda *'), findsOneWidget);

      // Lleva la lista al final (un arrastre puede caer sobre el campo de la
      // biografía, que tiene su propio scroll).
      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      for (var i = 0; i < 5; i++) {
        list.position.jumpTo(list.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.text('Guardar cambios'), findsOneWidget, reason: 'el botón está al final del formulario');
      expect(tester.takeException(), isNull);
    });
  }
}
