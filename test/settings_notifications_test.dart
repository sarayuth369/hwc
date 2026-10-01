import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/theme/app_theme_mode_controller.dart';
import 'package:bkknex_health_app/presentation/screens/settings/settings_screen.dart';

import 'support/fake_repositories.dart';

// NotificationService.setEnabled(true) reaches into flutter_local_notifications'
// real platform-plugin registration (FlutterLocalNotificationsPlatform.instance),
// which is never set up in a bare widget test -- the same class of
// limitation as camera capture or actual notification delivery: it can't
// be exercised here, only the read path (isEnabled/reminderTime, which
// just read SharedPreferences synchronously) can be tested honestly.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(WidgetTester tester, SharedPreferences prefs) async {
    // Settings is a long scrollable list; the default test surface leaves
    // most rows outside ListView's lazily built viewport+cache extent.
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AccessibilityModeController(prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => AppThemeModeController(prefs),
          ),
          ...fullProviderSet(prefs: prefs),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the reminder time row when already enabled', (tester) async {
    SharedPreferences.setMockInitialValues({
      'water_reminder_enabled_v1': true,
      'water_reminder_hour_v1': 9,
      'water_reminder_minute_v1': 30,
    });
    final prefs = await SharedPreferences.getInstance();
    await pumpSettings(tester, prefs);

    expect(find.byKey(const Key('waterReminderSwitch')), findsOneWidget);
    expect(find.byKey(const Key('waterReminderTimeTile')), findsOneWidget);
  });

  testWidgets('hides the reminder time row when disabled', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpSettings(tester, prefs);

    expect(find.byKey(const Key('waterReminderSwitch')), findsOneWidget);
    expect(find.byKey(const Key('waterReminderTimeTile')), findsNothing);
  });

  testWidgets('Health Report Reader and Family Mode tiles navigate',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpSettings(tester, prefs);

    await tester.tap(find.byKey(const Key('healthReportReaderTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('healthReportDisclaimer')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('familyModeTile')));
    await tester.pumpAndSettle();
    // Family Mode is now gated behind Premium (wired to PremiumGate this
    // pass); on the free tier (this test's default fake
    // SubscriptionRepository), the locked upsell shows instead of the
    // screen's own content.
    expect(find.byKey(const Key('premiumGateMessage')), findsOneWidget);
    expect(find.byKey(const Key('familyModeEmptyState')), findsNothing);
  });

  testWidgets(
    'a premium account sees the real Family Mode content, not the '
    'locked upsell (regression guard: gating must not lock out an '
    'actual entitled user)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AccessibilityModeController(prefs)),
            ChangeNotifierProvider(create: (_) => AppThemeModeController(prefs)),
            ...fullProviderSet(
              prefs: prefs,
              subscriptionRepository: FakePremiumSubscriptionRepository(),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('familyModeTile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('familyModeEmptyState')), findsOneWidget);
      expect(find.byKey(const Key('premiumGateMessage')), findsNothing);
    },
  );

  testWidgets(
    'Settings has no Subscription entry or Coming Soon section — Premium '
    'now has exactly one entry point (Profile), and Apple Health/Google '
    'Fit were cut rather than left as a dead placeholder',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await pumpSettings(tester, prefs);

      expect(find.byKey(const Key('subscriptionTile')), findsNothing);
      expect(find.text('Wearable Sync'), findsNothing);
    },
  );
}
