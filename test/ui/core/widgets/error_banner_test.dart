import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/ui/core/widgets/error_banner.dart';

void main() {
  testWidgets('ErrorBanner muestra qué falló, la explicación y Reintentar', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorBanner(
            title: 'No se pudo iniciar sesión',
            message: 'Email o contraseña incorrectos.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });
}
