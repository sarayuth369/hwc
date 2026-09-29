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
  /// loosely namespaced to this app to avoid colliding with another app's
  /// custom scheme on the same device.
  ///
  /// Deliberately NOT identical to the Android `applicationId`
  /// (`com.bkknex.bkknex_health_app`): that string contains underscores,
  /// which RFC 3986 forbids in a URI scheme (`ALPHA *( ALPHA / DIGIT / "+" /
  /// "-" / "." )`). `Uri.parse('com.bkknex.bkknex_health_app://...')`
  /// throws `FormatException: Illegal scheme character` in Dart, and the
  /// same RFC-3986 scheme grammar is what Go's `net/url` (and therefore
  /// Supabase's GoTrue backend) uses to validate `redirect_to` against the
  /// dashboard's Redirect URLs allow-list. A redirect URL with an invalid
  /// scheme fails that server-side match silently — GoTrue falls back to
  /// Site URL with no error surfaced to the client — which reproduces
  /// exactly the "confirmation email links to localhost" symptom this
  /// constant exists to fix. Hyphens are valid scheme characters, so this
  /// uses `bkknex-health-app` instead of `bkknex_health_app`.
  ///
  /// IMPORTANT — this string alone is not sufficient. Confirmed live
  /// (2026-09-29, via Supabase's Admin API `generateLink`, which returns
  /// the exact link a real confirmation email would contain): every
  /// `redirect_to` GoTrue receives that isn't already in the Supabase
  /// dashboard's Authentication → URL Configuration → Redirect URLs
  /// allow-list is silently replaced with Site URL, no error surfaced
  /// anywhere. Whenever this constant's value changes, the *exact* new
  /// string must also be added to that allow-list — updating this file,
  /// `scripts/patch_android_manifest.sh`, and the Android manifest is not
  /// enough on its own. There is no way to verify the dashboard side from
  /// this repo; re-run the `generateLink` check (see `HWC_REPORT.md`,
  /// "Auth confirmation forensic #3") after any dashboard change to
  /// confirm it actually took effect, rather than assuming a UI save
  /// succeeded.
  static const String authRedirectUrl =
      'com.bkknex.bkknex-health-app://login-callback/';

  /// Google's own published test ad unit IDs (safe to embed — Google
  /// documents these publicly for exactly this purpose: real ad requests
  /// that always serve a clearly-labeled test creative, never real inventory
  /// or real spend). Used whenever no production ad unit ID is supplied via
  /// `--dart-define`, so a build with no AdMob account configured still
  /// shows real (test) ads during development rather than nothing — and a
  /// build that's missing production IDs by mistake never silently serves
  /// real ads under a test app either.
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  static const String bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: _testBannerAdUnitId,
  );

  static const String appOpenAdUnitId = String.fromEnvironment(
    'ADMOB_APP_OPEN_AD_UNIT_ID',
    defaultValue: _testAppOpenAdUnitId,
  );

  /// True only when a *real* production ad unit ID was supplied via
  /// `--dart-define` — never true for Google's own test IDs above, so a
  /// debug build never claims "ads are live" when it's actually serving
  /// Google's test creative.
  static bool get hasProductionAdConfig =>
      bannerAdUnitId != _testBannerAdUnitId || appOpenAdUnitId != _testAppOpenAdUnitId;
}
