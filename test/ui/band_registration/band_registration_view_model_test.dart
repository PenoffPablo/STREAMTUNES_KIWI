import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/band_registration/view_models/band_registration_view_model.dart';
import 'package:streamtunes/utils/slug.dart';

/// Igual que la base: al crear la banda, el trigger `on_band_created` deja
/// al creador como dueño.
class _BandsWithOwnerTrigger extends FakeBandsRepository {
  _BandsWithOwnerTrigger(this.auth);
  final FakeAuthRepository auth;
  Band? lastCreated;

  @override
  Future<Band> createBand(Band band, String userId) async {
    final created = await super.createBand(band, userId);
    lastCreated = created;
    auth.grantBandRole(created.id);
    return created;
  }
}

void main() {
  late FakeAuthRepository auth;
  late _BandsWithOwnerTrigger bands;
  late SessionViewModel session;
  late BandRegistrationViewModel vm;

  setUp(() async {
    auth = FakeAuthRepository();
    bands = _BandsWithOwnerTrigger(auth);
    session = SessionViewModel(authRepo: auth, bandsRepo: bands, configRepo: FakeConfigRepository());
    await session.init();
    await session.signInWithEmail('fan@correo.com', 'pass123');
    vm = BandRegistrationViewModel(bandsRepo: bands, session: session);
  });

  tearDown(() {
    vm.dispose();
    session.dispose();
    auth.dispose();
  });

  test('un oyente con cuenta puede registrar una banda', () {
    expect(session.canRegisterBand, isTrue);
    expect(session.isMusician, isFalse);
  });

  test('registra la banda en revisión: todavía NO habilita Subir ni Mi Banda', () async {
    vm.selectGenre('Punk');
    final ok = await vm.submit(name: '  Los Fuzzers del Sótano ', location: 'Rosario', bio: 'Garage desde 2019.');

    expect(ok, isTrue, reason: vm.errorMessage);
    final band = bands.lastCreated!;
    expect(band.status, BandStatus.pending, reason: 'la aprueba un moderador');
    expect(band.name, 'Los Fuzzers del Sótano');
    expect(band.slug, 'los-fuzzers-del-sotano');
    expect(band.genre, 'Punk');
    expect(band.location, 'Rosario');

    expect(session.bandUnderReview?.id, band.id, reason: 'Cuenta muestra "en revisión"');
    expect(session.isMusician, isFalse, reason: 'una banda pendiente no puede publicar');
    expect(session.canRegisterBand, isFalse, reason: 'ya tiene una banda');
  });

  test('cuando el moderador la aprueba, aparecen las pestañas de músico', () async {
    await vm.submit(name: 'Los Fuzzers');
    final band = bands.lastCreated!;
    await bands.updateBand(band.copyWith(status: BandStatus.approved));

    await session.refreshUser(); // botón "¿Ya la aprobaron?"

    expect(session.isMusician, isTrue);
    expect(session.bandUnderReview, isNull);
  });

  test('sin nombre no se registra y explica por qué', () async {
    expect(await vm.submit(name: '   '), isFalse);
    expect(vm.errorMessage, contains('nombre'));
    expect(bands.lastCreated, isNull);
  });

  test('slugify arma un slug limpio para la URL y el QR', () {
    expect(slugify('Los Fuzzers del Sótano'), 'los-fuzzers-del-sotano');
    expect(slugify('  ¡Ñandú & Cía!  '), 'nandu-cia');
    expect(slugify('***'), 'banda');
  });
}
