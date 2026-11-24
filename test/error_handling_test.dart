import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/admin/view_models/admin_moderation_view_model.dart';
import 'package:streamtunes/ui/band_dashboard/view_models/band_dashboard_view_model.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

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
  group('describeError: el usuario ve QUÉ pasó, nunca el error técnico', () {
    test('sin internet', () {
      expect(describeError(const SocketException('Failed host lookup')), kNoConnectionMessage);
    });

    test('regla de negocio de la base (P0001): se muestra el mensaje del trigger', () {
      final e = PostgrestException(message: 'El monto supera el saldo pendiente', code: 'P0001');
      expect(describeError(e), 'El monto supera el saldo pendiente');
    });

    test('sin permiso (RLS / 42501): explica y sugiere volver a entrar', () {
      final e = PostgrestException(message: 'new row violates row-level security policy', code: '42501');
      final text = describeError(e);
      expect(text, contains('No tenés permiso'));
      expect(text, isNot(contains('row-level')));
    });

    test('login con datos incorrectos', () {
      const e = AuthException('Invalid login credentials', code: 'invalid_credentials');
      expect(describeError(e), 'Email o contraseña incorrectos.');
    });

    test('un error técnico desconocido no se filtra a la pantalla', () {
      final text = describeError(StateError('Bad state: Instance of _Foo'));
      expect(text, isNot(contains('Instance of')));
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

  group('Pagos a devolver', () {
    test('el moderador ve los pagos cobrados que no se registraron y los marca devueltos', () async {
      final payouts = FakePayoutsRepository(collected: {})
        ..addRejected(RejectedPayment(
          id: 'r1',
          mpPaymentId: '123456',
          amount: 2500,
          reason: 'Solo se puede donar a bandas aprobadas.',
          createdAt: DateTime(2026, 11, 24),
          bandName: 'Los Fuzzers',
        ));
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

  test('un aporte anónimo nunca muestra el nombre del donante', () {
    final d = Donation.fromJson({
      'id': 'd1',
      'band_id': _bandId,
      'amount': 1000,
      'is_public': false,
      'donor_name': null,
      'status': 'approved',
      'created_at': '2026-11-24T10:00:00Z',
    });
    expect(d.donorName, 'Fan anónimo');
    expect(d.donorUserId, isNull, reason: 'la base ya no expone donor_id al público');

    final pub = Donation.fromJson({
      'id': 'd2',
      'band_id': _bandId,
      'amount': 1000,
      'is_public': true,
      'donor_name': 'Juan Rock',
      'created_at': '2026-11-24T10:00:00Z',
    });
    expect(pub.donorName, 'Juan Rock');
  });

  testWidgets('ErrorBanner muestra qué falló, la explicación y Reintentar', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorBanner(
          title: 'No se pudo iniciar sesión',
          message: 'Email o contraseña incorrectos.',
          onRetry: () => retries++,
        ),
      ),
    ));
    expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });
}
