import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/core/config/env.dart';

/// Regression coverage for the email-confirmation / password-reset deep
/// link. This value is used in three places that must never drift apart:
/// [Env.authRedirectUrl] (passed as `emailRedirectTo`/`redirectTo` to
/// Supabase), the Android manifest's intent-filter (patched in by
/// `scripts/patch_android_manifest.sh` since `android/` is gitignored), and
/// the `applicationId` in `android/app/build.gradle.kts`. A mismatch in any
/// one of these silently reproduces the "confirmation link falls back to
/// Site URL / localhost" bug even though the other two look correct.
void main() {
  test(
    'Env.authRedirectUrl parses without throwing (regression: the scheme '
    'must never contain characters RFC 3986 forbids, e.g. "_" -- an '
    'earlier version of this constant was '
    'com.bkknex.bkknex_health_app://login-callback/, which Uri.parse '
    'rejects with FormatException("Illegal scheme character") because '
    'underscore is not a legal scheme character. Go\'s net/url -- and '
    'therefore Supabase\'s GoTrue backend -- uses the same RFC 3986 scheme '
    'grammar to validate redirect_to against the dashboard\'s allow-list, '
    'so an illegal scheme silently fails that match and GoTrue falls back '
    'to Site URL with no client-visible error. That reproduced exactly '
    'the "confirmation email links to localhost" bug this file guards '
    'against.)',
    () {
      expect(() => Uri.parse(Env.authRedirectUrl), returnsNormally);
    },
  );

  final redirectUri = Uri.parse(Env.authRedirectUrl);

  test('Env.authRedirectUrl is a well-formed custom-scheme deep link', () {
    expect(redirectUri.scheme, isNotEmpty);
    expect(
      redirectUri.scheme,
      isNot(contains('_')),
      reason: 'underscore is not a legal URI scheme character (RFC 3986)',
    );
    expect(redirectUri.host, 'login-callback');
    // Supabase's own docs example (`com.supabase://login-callback/`) and the
    // dashboard's Redirect URLs allow-list entry both include the trailing
    // slash; GoTrue's allow-list matching is not simple prefix matching, so
    // this must match byte-for-byte or the request silently falls back to
    // Site URL with no client-visible error.
    expect(Env.authRedirectUrl, endsWith('/'));
  });

  test(
    'the Android manifest patch script registers the same scheme/host '
    'Env.authRedirectUrl uses',
    () {
      // android/ itself is gitignored and regenerated fresh by `flutter
      // create` on every clean clone/CI run, so this checks the
      // version-controlled source of truth that actually reaches every
      // build, not a possibly-stale locally generated manifest.
      final script =
          File('scripts/patch_android_manifest.sh').readAsStringSync();
      expect(
        script,
        contains('DEEPLINK_SCHEME="${redirectUri.scheme}"'),
        reason:
            'patch_android_manifest.sh must register an intent-filter for '
            'the exact same scheme Env.authRedirectUrl uses, or the OS will '
            'never hand the confirmation link back to this app.',
      );
      expect(
        script,
        contains('android:host="${redirectUri.host}"'),
      );
    },
  );

  test('signUp/resetPassword redirect target is the app deep link, never a '
      'bare http(s) placeholder like the Supabase dashboard\'s Site URL', () {
    expect(redirectUri.scheme, isNot('http'));
    expect(redirectUri.scheme, isNot('https'));
  });
}
