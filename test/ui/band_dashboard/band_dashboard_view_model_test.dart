import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/utils/ids.dart';

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

/// Bandas con "señal" controlable: sin red, las consultas lanzan error
/// (como el repositorio Supabase real, que ya no traga los errores de red).
class _FlakyBandsRepository extends FakeBandsRepository {
  bool offline = false;
  bool followFails = false;
  bool statsFail = false;

  void _check() {
    if (offline) throw Exception('SocketException: sin señal');
  }

  @override
  Future<Band?> getBandById(String id) async {
    _check();
    return super.getBandById(id);
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    _check();
    return super.getBandBySlug(slug);
  }

  @override
  Future<bool> followBand(String bandId, String userId) async {
    _check();
    if (followFails) throw Exception('SocketException: se cortó la señal');
    // Igual que la base: band_follows.band_id es uuid.
    if (!isUuid(bandId)) throw Exception('invalid input syntax for type uuid: "$bandId"');
    return super.followBand(bandId, userId);
  }

  int statsCalls = 0;

  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    statsCalls++;
    if (statsFail) throw Exception('timeout');
    return super.getBandAggregatedStats(bandId);
  }
}

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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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

  group('Panel de banda', () {
    BandDashboardViewModel dashboard(_FlakyBandsRepository bands, FakePayoutsRepository payouts) =>
        BandDashboardViewModel(
          bandsRepo: bands,
          songsRepo: FakeSongsRepository(),
          payoutsRepo: payouts,
          bandId: _bandId,
          prefs: prefs,
        );

    test('un error de red en métricas NO se guarda en caché ni tira abajo el panel', () async {
      final bands = _FlakyBandsRepository()..statsFail = true;
      final vm = dashboard(bands, FakePayoutsRepository());
      addTearDown(vm.dispose);

      await vm.loadDashboard();

      expect(vm.band, isNotNull, reason: 'el resto del panel carga igual');
      expect(vm.errorMessage, isNull);
      expect(vm.metricsError, isNotNull);
      expect(
        prefs.getString('metrics_day_$_bandId'),
        isNull,
        reason: 'un fallo no puede quedar cacheado todo el día como si fueran ceros',
      );
    });

    test('muestra el estado de cuenta con KIWI: recaudado, cobrado y saldo', () async {
      final payouts = FakePayoutsRepository(collected: {_bandId: (name: 'Los Fuzzers', gross: 10000, net: 9400)});
      await payouts.registerPayout(bandId: _bandId, amount: 4000, reference: 'OP-1');

      final vm = dashboard(_FlakyBandsRepository(), payouts);
      addTearDown(vm.dispose);
      await vm.loadDashboard();

      final b = vm.balance!;
      expect(b.collected, 10000);
      expect(b.netCollected, 9400);
      expect(b.mercadoPagoFees, 600);
      expect(b.kiwiFee, 1880, reason: '20% del neto para sostener la app');
      expect(b.bandShare, 7520);
      expect(b.paid, 4000);
      expect(b.pending, 3520);
      expect(vm.payouts.single.reference, 'OP-1');
    });
  });

  group('Panel de banda: si falla el saldo, se conserva el último', () {
    test('muestra el aviso pero no borra el saldo cargado', () async {
      SharedPreferences.setMockInitialValues({});
      final payouts = _ManualPayouts()..bandBalance = _balance(5400);
      final vm = BandDashboardViewModel(
        bandsRepo: FakeBandsRepository(),
        songsRepo: FakeSongsRepository(),
        payoutsRepo: payouts,
        bandId: _bandId,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(vm.dispose);
      await vm.refreshAccount();
      expect(vm.balance!.pending, 5400);

      payouts.failBand = true;
      await vm.refreshAccount();

      expect(vm.balance!.pending, 5400, reason: 'el saldo anterior sigue visible');
      expect(vm.accountError, contains('No se pudo actualizar tu saldo con KIWI'));
      expect(vm.accountError, contains('No hay conexión'));
    });
  });

  group('Métricas del día (se renuevan a las 00:00)', () {
    late DateTime now;
    late _FlakyBandsRepository bands;

    BandDashboardViewModel open() {
      final vm = BandDashboardViewModel(
        bandsRepo: bands,
        songsRepo: FakeSongsRepository(),
        bandId: _bandId,
        prefs: prefs,
        clock: () => now,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    setUp(() => bands = _FlakyBandsRepository());

    test('el mismo día se muestran desde el caché: no se vuelven a calcular', () async {
      now = DateTime(2026, 11, 26, 10);
      final first = open();
      await first.loadDashboard();
      expect(bands.statsCalls, 1);
      expect(first.isMetricsFromCache, isFalse);
      expect(first.report, isNotNull, reason: 'el desglose por tema sale del isolate');

      now = DateTime(2026, 11, 26, 23, 59);
      final again = open();
      await again.loadDashboard();
      expect(bands.statsCalls, 1, reason: 'hasta las 00:00 no se consulta la base de nuevo');
      expect(again.isMetricsFromCache, isTrue);
      expect(again.report!.totalPlays, first.report!.totalPlays);
    });

    test('pasadas las 00:00 se calculan las métricas del nuevo día', () async {
      now = DateTime(2026, 11, 26, 23, 50);
      await open().loadDashboard();

      now = DateTime(2026, 11, 27, 0, 1);
      final nextDay = open();
      await nextDay.loadDashboard();
      expect(bands.statsCalls, 2, reason: 'es otro día de calendario, no importa que pasaron 11 minutos');
      expect(nextDay.isMetricsFromCache, isFalse);
    });

    test('la cuenta regresiva apunta a la próxima medianoche', () {
      now = DateTime(2026, 11, 26, 22, 30);
      expect(open().timeUntilNextRefresh, const Duration(hours: 1, minutes: 30));
    });
  });
}
