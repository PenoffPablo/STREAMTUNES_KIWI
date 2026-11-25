import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository_fake.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_public/view_models/donation_view_model.dart';

class _FakeLauncher extends ExternalLauncherService {
  _FakeLauncher({this.canOpen = true});
  final bool canOpen;
  final List<String> opened = [];

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);
    return canOpen;
  }
}

/// Pasarela que devuelve un checkout y registra qué se le pidió.
class _FakeCheckout implements PaymentsRepository {
  final List<({String donationId, String bandId, double amount, bool anonymous})> requests = [];

  @override
  Future<String?> createDonationCheckout({
    required String donationId,
    required String bandId,
    required double amount,
    String? message,
    bool isAnonymous = false,
  }) async {
    requests.add((donationId: donationId, bandId: bandId, amount: amount, anonymous: isAnonymous));
    return 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=test';
  }
}

void main() {
  group('DonationViewModel (KIWI cobra con el checkout de Mercado Pago)', () {
    final band = Band(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      name: 'Los Fuzzers',
      slug: 'los-fuzzers',
      genre: 'Rock',
      createdAt: DateTime(2026),
    );

    test('calcula la comisión estimada y el neto para la banda', () {
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: _FakeCheckout(),
        launcher: _FakeLauncher(),
      );
      vm.setAmountText('2000');
      expect(vm.estimatedFee, 120);
      expect(vm.netBandAmount, 1880);
      vm.dispose();
    });

    test('abre el checkout de KIWI con el id del intento (para que el webhook no duplique)', () async {
      final checkout = _FakeCheckout();
      final launcher = _FakeLauncher();
      final vm = DonationViewModel(band: band, currentUser: null, paymentsRepo: checkout, launcher: launcher);
      vm.setAmountText('1500');
      vm.setAnonymous(true);

      await vm.startCheckout();

      expect(checkout.requests.single.donationId, vm.donationId);
      expect(checkout.requests.single.amount, 1500);
      expect(checkout.requests.single.anonymous, isTrue);
      expect(launcher.opened.single, contains('mercadopago'));
      expect(vm.checkoutOpened, isTrue);
      expect(vm.errorMessage, isNull);
      expect(vm.isOpeningCheckout, isFalse);
      vm.dispose();
    });

    test('cada intento de pago tiene su propio id (dos pagos = dos aportes)', () async {
      final checkout = _FakeCheckout();
      final vm = DonationViewModel(band: band, currentUser: null, paymentsRepo: checkout, launcher: _FakeLauncher());
      await vm.startCheckout();
      await vm.startCheckout();
      final ids = checkout.requests.map((r) => r.donationId).toList();
      expect(ids, hasLength(2));
      expect(ids.first, isNot(ids.last));
      expect(vm.donationId, ids.last);
      vm.dispose();
    });

    test('sin pasarela disponible informa el error (no hay caminos alternativos)', () async {
      final launcher = _FakeLauncher();
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: FakePaymentsRepository(), // devuelve null (sin init_point)
        launcher: launcher,
      );
      await vm.startCheckout();
      expect(launcher.opened, isEmpty);
      expect(vm.checkoutOpened, isFalse);
      expect(vm.errorMessage, contains('no están disponibles'));
      vm.dispose();
    });

    test('si no se puede abrir Mercado Pago en el dispositivo, lo informa', () async {
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: _FakeCheckout(),
        launcher: _FakeLauncher(canOpen: false),
      );
      await vm.startCheckout();
      expect(vm.checkoutOpened, isFalse);
      expect(vm.errorMessage, contains('No se pudo abrir'));
      vm.dispose();
    });

    test('respeta el tope de app_config: no ofrece ni cobra montos mayores', () async {
      final checkout = _FakeCheckout();
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: checkout,
        launcher: _FakeLauncher(),
        maxAmount: 5000,
      );
      expect(vm.presets, isNot(contains(10000)));

      vm.setAmountText('6000');
      expect(vm.exceedsMax, isTrue);
      expect(vm.canPay, isFalse);
      await vm.startCheckout();
      expect(checkout.requests, isEmpty);
      vm.dispose();
    });
  });
}
