import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Future / async-await', () {
    test('retry reintenta con backoff y finalmente devuelve el valor', () async {
      var calls = 0;
      final value = await retry(() async {
        calls++;
        if (calls < 3) throw Exception('falla de red');
        return 'ok';
      }, delay: const Duration(milliseconds: 1));
      expect(value, 'ok');
      expect(calls, 3);
    });

    test('retry relanza el error después del último intento', () async {
      var calls = 0;
      await expectLater(
        retry(
          () async {
            calls++;
            throw Exception('siempre falla');
          },
          attempts: 2,
          delay: const Duration(milliseconds: 1),
        ),
        throwsException,
      );
      expect(calls, 2);
    });

    test('withNetworkTimeout convierte el timeout en NetworkTimeoutException', () async {
      final never = Completer<int>().future;
      await expectLater(
        never.withNetworkTimeout(const Duration(milliseconds: 10)),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test('describeError desarma el ParallelWaitError de (f1, f2).wait', () async {
      try {
        await (Future.value(1), Future<int>.error(Exception('sin señal'))).wait;
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<ParallelWaitError>());
        expect(describeError(e), 'sin señal');
      }
    });
  });

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
}
