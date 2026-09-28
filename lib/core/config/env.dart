/// Compile-time configuration. All values come from `--dart-define` at build
/// time — nothing here is a literal secret, and no AI-provider or
/// Supabase service-role key is ever read or stored client-side.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base URL of the Cloudflare Worker AI gateway (Worker B / bkknex-worker).
  /// The app only ever calls documented routes on this host
  /// (`/api/ai/chat`, `/api/ai/insight`, `/api/ai/voice/*`) — no vendor name
  /// or provider branching lives in this client.
  static const String workerBaseUrl = String.fromEnvironment(
    'WORKER_BASE_URL',
    defaultValue: 'https://worker.bkknex.invalid',
  );

  static const String posthogApiKey =
      String.fromEnvironment('POSTHOG_API_KEY');

  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://app.posthog.com',
  );

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Deep link the app registers natively (see AndroidManifest's intent
  /// filter, patched in via `scripts/patch_android_manifest.sh`) so Supabase
  /// Auth's email-confirmation / password-reset links open this app
  /// directly instead of falling back to whatever placeholder "Site URL"
  /// is set in the Supabase dashboard (e.g. `localhost:3000`, which no
  /// device can ever reach). Not a secret — just a fixed scheme string,
  /// namespaced to this app's own application ID to avoid colliding with
  /// another app's custom scheme on the same device.
  static const String authRedirectUrl =
      'com.bkknex.bkknex_health_app://login-callback/';
}
