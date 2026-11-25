import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

/// Saldos que "suben" cuando se agrega un pago: simula lo que calcula la base
/// (band_balances) a partir de las donaciones verificadas.
class _LivePayouts extends FakePayoutsRepository {
  _LivePayouts() : super(collected: {});
  double gross = 0;
  double net = 0;
  int balanceCalls = 0;
  bool fail = false;

  BandBalance _current() =>
      BandBalance(bandId: _bandId, bandName: 'Los Fuzzers', collected: gross, netCollected: net, paid: 0, pending: net);

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

BandBalance _balance(double pending) => BandBalance(
  bandId: _bandId,
  bandName: 'Los Fuzzers',
  collected: pending,
  netCollected: pending,
  paid: 0,
  pending: pending,
);

/// Saldos controlados a mano: cada pedido queda esperando un Completer, así el
/// test decide en qué orden "responde el servidor".
class _ManualPayouts extends FakePayoutsRepository {
  _ManualPayouts() : super(collected: {});
  final List<Completer<List<BandBalance>>> pendingAll = [];
  BandBalance? bandBalance = _balance(100);
  bool failBand = false;

  @override
  Future<List<BandBalance>> getAllBalances() {
    final c = Completer<List<BandBalance>>();
    pendingAll.add(c);
    return c.future;
  }

  @override
  Future<BandBalance> getBandBalance(String bandId) async {
    if (failBand) throw const SocketException('Failed host lookup');
    return bandBalance!;
  }

  @override
  Future<List<BandPayout>> getPayouts(String bandId) async => const [];
}

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
      vm = AdminModerationViewModel(moderationRepo: FakeModerationRepository(), configRepo: FakeConfigRepository());
    });
  });

  group('Liquidaciones (moderación)', () {
    AdminModerationViewModel admin(FakePayoutsRepository payouts) => AdminModerationViewModel(
      moderationRepo: FakeModerationRepository(),
      configRepo: FakeConfigRepository(),
      payoutsRepo: payouts,
    );

    test('el moderador ve cuánto debe KIWI y registra un pago que baja el saldo', () async {
      final payouts = FakePayoutsRepository(collected: {_bandId: (name: 'Los Fuzzers', gross: 5000, net: 4700)});
      final vm = admin(payouts);
      addTearDown(vm.dispose);
      await vm.loadModerationData();
      expect(vm.totalPending, 4700);

      expect(await vm.registerPayout(bandId: _bandId, amount: 4700, reference: 'OP-99'), isTrue);

      expect(vm.totalPending, 0);
      expect(vm.balances.single.paid, 4700);
      expect(vm.isPaying(_bandId), isFalse);
    });

    test('no se puede liquidar más que el saldo pendiente', () async {
      final payouts = FakePayoutsRepository(collected: {_bandId: (name: 'Los Fuzzers', gross: 1000, net: 940)});
      final vm = admin(payouts);
      addTearDown(vm.dispose);
      await vm.loadModerationData();

      expect(await vm.registerPayout(bandId: _bandId, amount: 1000), isFalse);
      expect(vm.payoutError, contains('supera el saldo pendiente'));
      expect(vm.totalPending, 940, reason: 'el saldo no cambia');
    });
  });

  group('Panel de moderación: la última recarga gana', () {
    test('si la primera respuesta llega última, NO pisa los números nuevos', () async {
      final payouts = _ManualPayouts();
      final vm = AdminModerationViewModel(
        moderationRepo: FakeModerationRepository(),
        configRepo: FakeConfigRepository(),
        payoutsRepo: payouts,
      );
      addTearDown(vm.dispose);

      final first = vm.refreshMoney();
      final second = vm.refreshMoney();
      await pumpEventQueue();
      expect(payouts.pendingAll, hasLength(2));

      payouts.pendingAll[1].complete([_balance(900)]); // la nueva responde primero
      payouts.pendingAll[0].complete([_balance(100)]); // la vieja llega tarde
      await (first, second).wait;

      expect(vm.totalPending, 900);
      expect(vm.moneyError, isNull);
    });
  });

  group('Pagos a devolver', () {
    test('el moderador ve los pagos cobrados que no se registraron y los marca devueltos', () async {
      final payouts = FakePayoutsRepository(collected: {})
        ..addRejected(
          RejectedPayment(
            id: 'r1',
            mpPaymentId: '123456',
            amount: 2500,
            reason: 'Solo se puede donar a bandas aprobadas.',
            createdAt: DateTime(2026, 11, 24),
            bandName: 'Los Fuzzers',
          ),
        );
      final vm = AdminModerationViewModel(
        moderationRepo: FakeModerationRepository(),
        configRepo: FakeConfigRepository(),
        payoutsRepo: payouts,
      );
      addTearDown(vm.dispose);
      await vm.loadModerationData();

      expect(vm.pendingRefunds.single.mpPaymentId, '123456');
      expect(vm.totalToRefund, 2500);

      expect(await vm.markRefunded('r1'), isTrue);
      expect(vm.pendingRefunds, isEmpty);

      expect(await vm.markRefunded('r1'), isFalse, reason: 'no se marca dos veces');
      expect(vm.payoutError, contains('ya estaba marcado'));
    });
  });
}
