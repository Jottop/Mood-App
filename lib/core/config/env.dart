/// Configuración de Supabase. El URL del proyecto es público y va por
/// default; la publishable key NUNCA va hardcodeada en el repositorio: se
/// inyecta al compilar con `--dart-define`.
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable_key>
/// ```
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://aieavhmgfujnrzufvcpe.supabase.co',
  );
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Modo dev sin claves (p. ej. `flutter analyze` o builds sin dart-define).
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}