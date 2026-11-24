import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

/// Saldos que "suben" cuando se agrega un pago: simula lo que calcula la base
/// (band_balances) a partir de las donaciones verificadas.
class _LivePayouts extends FakePayoutsRepository {
  _LivePayouts() : super(collected: {});
  double gross = 0;
  double net = 0;
  int balanceCalls = 0;
  bool fail = false;

  BandBalance _current() => BandBalance(
        bandId: _bandId,
        bandName: 'Los Fuzzers',
        collected: gross,
        netCollected: net,
        paid: 0,
        pending: net,
      );

  @override
  Future<List<BandBalance>> getAllBalances() async {
    balanceCalls++;
    if (fail) throw Exception('permission denied for function band_balances');
    return [_current()];
  }

  @override
  Future<BandBalance> getBandBalance(String bandId) async {
    balanceCalls++;
    return _current();
  }
}

Donation _verifiedPayment({required String id, required String bandId, double amount = 10, double net = 9.58}) =>
    Donation(
      id: id,
      bandId: bandId,
      donorName: 'Fan',
      amountArs: amount,
      netAmount: net,
      mpPaymentId: 'mp-$id',
      bandName: 'Los Fuzzers',
      createdAt: DateTime.now(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Panel de moderación en vivo', () {
    late FakeDonationsRepository donations;
    late _LivePayouts payouts;
    late AdminModerationViewModel vm;

    setUp(() async {
      donations = FakeDonationsRepository();
      payouts = _LivePayouts();
      vm = AdminModerationViewModel(
        moderationRepo: FakeModerationRepository(),
        configRepo: FakeConfigRepository(),
        payoutsRepo: payouts,
        donationsRepo: donations,
      );
      await vm.init();
    });

    tearDown(() {
      vm.dispose();
      donations.dispose();
    });

    test('cuando el webhook aprueba un pago, el panel se actualiza solo', () async {
      expect(vm.totalPending, 0);
      expect(vm.recentPayments, isEmpty);

      // El webhook registra un pago verificado (llega por realtime).
      payouts
        ..gross = 10
        ..net = 9.58;
      donations.addApproved(_verifiedPayment(id: 'p1', bandId: _bandId));
      await pumpEventQueue();

      expect(vm.totalCollected, 10);
      expect(vm.totalFees, closeTo(0.42, 0.001));
      expect(vm.totalPending, 9.58, reason: 'KIWI le debe el neto a la banda');
      final pago = vm.recentPayments.single;
      expect(pago.bandName, 'Los Fuzzers');
      expect(pago.amountArs, 10);
      expect(pago.netOrAmount, 9.58);
    });

    test('si los saldos no cargan, se muestra el error (no un panel vacío)', () async {
      payouts.fail = true;
      await vm.refreshMoney();
      expect(vm.moneyError, contains('No se pudieron cargar los saldos'));
    });

    test('al cerrar el panel deja de escuchar pagos', () async {
      final callsBefore = payouts.balanceCalls;
      vm.dispose();
      donations.addApproved(_verifiedPayment(id: 'p2', bandId: _bandId));
      await pumpEventQueue();
      expect(payouts.balanceCalls, callsBefore);
      // Se recrea para que el tearDown no falle al hacer dispose dos veces.
      vm = AdminModerationViewModel(
        moderationRepo: FakeModerationRepository(),
        configRepo: FakeConfigRepository(),
      );
    });
  });

  group('Panel de la banda en vivo', () {
    test('un pago para ESTA banda actualiza "Tus aportes"; uno de otra banda no', () async {
      final prefs = await SharedPreferences.getInstance();
      final donations = FakeDonationsRepository();
      final payouts = _LivePayouts();
      final vm = BandDashboardViewModel(
        bandsRepo: FakeBandsRepository(),
        songsRepo: FakeSongsRepository(),
        payoutsRepo: payouts,
        donationsRepo: donations,
        bandId: _bandId,
        prefs: prefs,
      );
      addTearDown(() {
        vm.dispose();
        donations.dispose();
      });
      await vm.loadDashboard();
      expect(vm.balance!.pending, 0);

      final callsBefore = payouts.balanceCalls;
      donations.addApproved(_verifiedPayment(id: 'otra', bandId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'));
      await pumpEventQueue();
      expect(payouts.balanceCalls, callsBefore, reason: 'pagos de otras bandas no la afectan');

      payouts
        ..gross = 10
        ..net = 9.58;
      donations.addApproved(_verifiedPayment(id: 'mia', bandId: _bandId));
      await pumpEventQueue();
      expect(vm.balance!.pending, 9.58);
    });
  });
}
