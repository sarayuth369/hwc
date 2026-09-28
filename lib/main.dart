import 'dart:async';

import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/sentry/sentry_scrubber.dart';
import 'data/supabase/supabase_client_provider.dart';
import 'presentation/app_providers.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await initSupabase();

    if (Env.posthogApiKey.isNotEmpty) {
      final config = PostHogConfig(Env.posthogApiKey)..host = Env.posthogHost;
      await Posthog().setup(config);
    }

    final prefs = await SharedPreferences.getInstance();

    if (Env.sentryDsn.isEmpty) {
      runApp(AppProviders(prefs: prefs, child: const HealthApp()));
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.beforeSend = scrubBeforeSend;
      },
      appRunner: () =>
          runApp(AppProviders(prefs: prefs, child: const HealthApp())),
    );
  }, (error, stack) {
    // Fallback so an early startup crash still surfaces instead of a blank
    // screen; Sentry (once initialized) captures it separately.
    debugPrint('Unhandled startup error: $error');
  });
}
