/// Configuración de entorno inyectada en compilación con `--dart-define`.
///
/// Ejemplo:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
abstract final class Environment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fajwcwabcdxetuffoiuh.supabase.co',
  );

  /// Clave *publishable* (pública por diseño, protegida por RLS). Los secretos
  /// (Mercado Pago, service role, FCM) viven solo en las Edge Functions.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Z-GmSTHbO64JDaBa3KXIzQ_9FuQ08rY',
  );

  static const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
