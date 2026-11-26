import 'dart:async';
import 'dart:io' show HandshakeException, HttpException, SocketException;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthException,
        AuthInvalidJwtException,
        AuthRetryableFetchException,
        AuthSessionMissingException,
        AuthWeakPasswordException,
        FunctionException,
        PostgrestException,
        StorageException;

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

/// Mensaje cuando no hay internet (o el servidor no es alcanzable).
const String kNoConnectionMessage =
    'No hay conexión a internet. Revisá tu señal o tu Wi-Fi e intentá de nuevo.';

/// Mensaje genérico cuando el error no tiene una explicación útil para el usuario.
const String kUnexpectedErrorMessage =
    'Ocurrió un error inesperado. Intentá de nuevo en unos segundos.';

/// Convierte cualquier error en un texto que el USUARIO entienda: qué pasó y,
/// si se puede, qué hacer. Nunca devuelve el texto técnico crudo
/// (`PostgrestException(message: ..., code: P0001, ...)`): el detalle técnico
/// se manda a la consola con `debugPrint` para quien desarrolla.
///
/// * `ParallelWaitError` (lo lanza `(f1, f2).wait`): toma el primer error real.
/// * Errores propios ([AppException]): su mensaje ya es para el usuario.
/// * Red, Supabase (base, login, funciones, archivos): mensajes traducidos.
String describeError(Object error) {
  final message = _describe(error);
  if (error is! AppException && error is! ParallelWaitError) {
    debugPrint('[describeError] ${error.runtimeType}: $error');
  }
  return message;
}

String _describe(Object error) {
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
  // Storage responde con su propio error (formato, tamaño, permisos): se
  // revisa antes que la red para no mostrar "sin conexión" si el servidor
  // contestó y rechazó el archivo.
  if (error is StorageException) return _describeStorage(error);
  if (_isNetworkError(error)) return kNoConnectionMessage;
  if (error is PostgrestException) return _describeDatabase(error);
  if (error is AuthException) return _describeAuth(error);
  if (error is FunctionException) return _describeFunction(error);
  if (error is FormatException) {
    return 'El servidor respondió con datos inesperados. Intentá de nuevo en unos segundos.';
  }

  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return _looksTechnical(text) ? kUnexpectedErrorMessage : text;
}

/// Sin red: socket, TLS, DNS o el cliente HTTP que no llegó al servidor.
bool _isNetworkError(Object error) {
  if (error is SocketException || error is HandshakeException || error is HttpException) {
    return true;
  }
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString();
  return error.runtimeType.toString() == 'ClientException' ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed') ||
      text.contains('Network is unreachable') ||
      text.contains('SocketException');
}

/// Errores de la base (PostgREST / PostgreSQL).
String _describeDatabase(PostgrestException e) {
  final msg = e.message.toLowerCase();
  switch (e.code) {
    // Reglas de negocio de los triggers (validate_payout, validate_donation,
    // límites de temas/álbumes): el mensaje ya está escrito para el usuario.
    case 'P0001':
      return e.message;
    case '42501':
      return 'No tenés permiso para hacer esto. Si recién te dieron permisos, '
          'cerrá sesión y volvé a entrar.';
    case '23505':
      return 'Eso ya estaba registrado.';
    case '23503':
      return 'No se encontró un dato relacionado: puede que se haya borrado. Actualizá la pantalla.';
    case '23514':
    case '22001':
      return 'Algún dato no es válido (por ejemplo, un texto demasiado largo o un monto en cero).';
    case '22P02':
      return 'Alguno de los datos tiene un formato inválido.';
    case 'PGRST116':
      return 'No se encontró lo que buscabas: puede que se haya borrado.';
    case 'PGRST301':
    case 'PGRST303':
      return 'Tu sesión expiró. Volvé a iniciar sesión.';
    case 'PGRST202':
      return 'Esta función todavía no está disponible en el servidor.';
  }
  if (msg.contains('row-level security') || msg.contains('permission denied')) {
    return 'No tenés permiso para hacer esto. Si recién te dieron permisos, cerrá sesión y volvé a entrar.';
  }
  if (msg.contains('jwt expired')) return 'Tu sesión expiró. Volvé a iniciar sesión.';
  return 'El servidor no pudo completar la operación. Intentá de nuevo en unos segundos.';
}

/// Errores de login y registro (Supabase Auth).
String _describeAuth(AuthException e) {
  if (e is AuthWeakPasswordException) {
    return 'La contraseña es muy débil: usá al menos 6 caracteres, mezclando letras y números.';
  }
  if (e is AuthSessionMissingException || e is AuthInvalidJwtException) {
    return 'Tu sesión expiró. Volvé a iniciar sesión.';
  }
  final code = e.code ?? '';
  final msg = e.message.toLowerCase();
  if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
    return 'Email o contraseña incorrectos.';
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return 'Tenés que confirmar tu email antes de entrar. Revisá tu casilla (y la carpeta de spam).';
  }
  if (code == 'user_already_exists' || msg.contains('already registered')) {
    return 'Ya existe una cuenta con ese email. Probá iniciar sesión.';
  }
  if (code == 'weak_password') {
    return 'La contraseña es muy débil: usá al menos 6 caracteres, mezclando letras y números.';
  }
  if (code == 'email_address_invalid' || msg.contains('invalid email') || msg.contains('unable to validate email')) {
    return 'El email no es válido. Revisá que esté bien escrito.';
  }
  if (code == 'anonymous_provider_disabled' || msg.contains('anonymous sign-ins are disabled')) {
    return 'El ingreso como invitado no está habilitado. Creá una cuenta o iniciá sesión.';
  }
  if (code.contains('rate_limit') || e.statusCode == '429') {
    return 'Hiciste demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.';
  }
  return 'No se pudo completar el inicio de sesión. Intentá de nuevo.';
}

/// Errores de las Edge Functions (pagos con Mercado Pago, etc.).
String _describeFunction(FunctionException e) {
  final details = e.details;
  // Nuestras funciones responden {"error": "<mensaje en español>"}.
  final serverMessage = details is Map ? details['error'] as String? : null;
  if (e.status == 401 || e.status == 403) {
    return 'No tenés permiso para hacer esto. Volvé a iniciar sesión.';
  }
  if (e.status >= 500) {
    return 'El servicio de pagos no respondió. Intentá de nuevo en unos minutos.';
  }
  if (serverMessage != null && serverMessage.isNotEmpty && !_looksTechnical(serverMessage)) {
    return serverMessage;
  }
  return 'No se pudo completar la operación. Intentá de nuevo.';
}

/// Errores al subir o leer archivos (Supabase Storage).
String _describeStorage(StorageException e) {
  final status = e.statusCode ?? '';
  final msg = e.message.toLowerCase();
  if (status == '413' || msg.contains('payload too large') || msg.contains('exceeded the maximum')) {
    return 'El archivo es demasiado grande para subirlo.';
  }
  if (status == '415' || msg.contains('mime type') || msg.contains('invalid_mime')) {
    return 'Ese formato de archivo no está permitido. Para audio, subí MP3, M4A o WAV; para imágenes, JPG, PNG o WEBP.';
  }
  if (status == '403' || status == '401' || msg.contains('row-level security')) {
    return 'No tenés permiso para subir archivos en esta banda.';
  }
  return 'El servidor no aceptó el archivo. Probá con otro archivo o intentá de nuevo en unos minutos.';
}

/// Heurística: el texto parece un volcado técnico, no un mensaje para personas.
bool _looksTechnical(String text) {
  return text.contains('Exception(') ||
      text.contains('Error(') ||
      text.contains('code:') ||
      text.contains('Instance of') ||
      text.startsWith("type '") ||
      text.contains('Null check operator') ||
      text.contains('RangeError') ||
      text.contains('StackTrace') ||
      text.contains('dart:') ||
      text.contains('package:');
}
