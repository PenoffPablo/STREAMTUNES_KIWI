import 'dart:async';

/// Tiempo máximo de espera de una operación de red antes de abortarla.
const Duration kNetworkTimeout = Duration(seconds: 15);

/// Error de dominio con un mensaje apto para mostrar al usuario.
class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// La red no respondió a tiempo (por ejemplo, sin señal en el sótano).
class NetworkTimeoutException extends AppException {
  const NetworkTimeoutException()
      : super('La conexión tardó demasiado. Revisá tu señal e intentá de nuevo.');
}

extension FutureNetworkX<T> on Future<T> {
  /// Aplica [kNetworkTimeout] y transforma el `TimeoutException` genérico en
  /// una [NetworkTimeoutException] con un mensaje claro.
  Future<T> withNetworkTimeout([Duration timeout = kNetworkTimeout]) =>
      this.timeout(timeout, onTimeout: () => throw const NetworkTimeoutException());
}

/// Reintenta [action] hasta [attempts] veces con backoff exponencial
/// (delay, 2·delay, 4·delay...) usando `Future.delayed`.
///
/// [retryIf] decide qué errores vale la pena reintentar (por defecto, todos).
Future<T> retry<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 400),
  bool Function(Object error)? retryIf,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } catch (e) {
      final canRetry = attempt < attempts && (retryIf?.call(e) ?? true);
      if (!canRetry) rethrow;
      await Future<void>.delayed(delay * (1 << (attempt - 1)));
    }
  }
}

/// Convierte cualquier error en un texto legible para la UI.
///
/// * `ParallelWaitError` (lo lanza `(f1, f2).wait`): toma el primer error real.
/// * `Exception: xxx` -> `xxx`.
String describeError(Object error) {
  if (error is ParallelWaitError) {
    final errors = error.errors;
    final first = switch (errors) {
      (Object? a, Object? b) => a ?? b,
      (Object? a, Object? b, Object? c) => a ?? b ?? c,
      (Object? a, Object? b, Object? c, Object? d) => a ?? b ?? c ?? d,
      (Object? a, Object? b, Object? c, Object? d, Object? e) => a ?? b ?? c ?? d ?? e,
      (Object? a, Object? b, Object? c, Object? d, Object? e, Object? f) =>
        a ?? b ?? c ?? d ?? e ?? f,
      (Object? a, Object? b, Object? c, Object? d, Object? e, Object? f, Object? g) =>
        a ?? b ?? c ?? d ?? e ?? f ?? g,
      final List<Object?> list => list.firstWhere((e) => e != null, orElse: () => null),
      _ => null,
    };
    if (first is AsyncError) return describeError(first.error);
    if (first != null) return describeError(first);
  }
  if (error is AppException) return error.message;
  if (error is TimeoutException) return const NetworkTimeoutException().message;
  return error.toString().replaceFirst('Exception: ', '');
}
