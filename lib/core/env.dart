/// Reads Supabase config from --dart-define at build time.
/// Run with: flutter run --dart-define-from-file=env.json
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Run with --dart-define-from-file=env.json (see env.example.json).',
      );
    }
  }
}
