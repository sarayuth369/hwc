import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/app.dart';
import 'package:bkknex_health_app/presentation/app_providers.dart';

/// Regression test for a real startup crash: a debug build made without
/// `--dart-define=SUPABASE_URL=...`/`SUPABASE_ANON_KEY=...` (which is what
/// `flutter build apk --debug` does here, and what CI's build step does
/// too) left `Env.hasSupabaseConfig` false, `Supabase.initialize` was never
/// called, and `AppProviders` unconditionally accessed `Supabase.instance`
/// anyway — crashing on device with a raw assertion. This test boots the
/// real `AppProviders`/`HealthApp` pair exactly as `main.dart` does,
/// without ever calling `Supabase.initialize` (this test binary has no
/// `--dart-define` either, matching the exact conditions that crashed).
void main() {
  testWidgets(
      'AppProviders does not crash and shows a plain message '
      'when Supabase is not configured', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      AppProviders(prefs: prefs, child: const HealthApp()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('backendNotConfiguredMessage')),
      findsOneWidget,
    );
  });
}
