// Renders the required onboarding -> Home -> Quick Add -> Senior Mode
// flow to real PNG files via Flutter's golden-file test harness. This VPS
// has no Android emulator/display, so golden files (rendered by the test
// framework's software rasterizer, not a live device) are the literal
// screenshot evidence for BKK-78's acceptance criteria.
//
// Regenerated for the Phase 1 UI/UX redesign (new theme tokens, bottom-nav
// shell, restyled screens) — the pixel diffs against the pre-redesign
// baseline are expected and intentional, not a regression. See
// D:\FlutterProjects\gpt-claude\HWC_REPORT.md for the redesign record.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/theme/app_theme.dart';
import 'package:bkknex_health_app/core/theme/senior_mode_theme.dart';
import 'package:bkknex_health_app/data/local/sync_service.dart';
import 'package:bkknex_health_app/domain/models/accessibility_mode.dart';
import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/screens/home/home_screen.dart';
import 'package:bkknex_health_app/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:bkknex_health_app/presentation/screens/quick_actions/quick_add_sheet.dart';

import 'support/fake_repositories.dart';

// A fixed clock so `HomeScreen`'s greeting ("Good Morning"/"Good Afternoon"/
// "Good Evening" -- different lengths) can't change these goldens depending
// on the real hour a test happens to run at (confirmed root cause of a
// previously-mysterious, reproducible-yet-code-unrelated golden diff: see
// HWC_DECISIONS.md).
DateTime _fixedMorning() => DateTime(2026, 1, 1, 9);

Widget _themedApp(
  Widget home, {
  required AccessibilityModeController controller,
  required List<SingleChildWidget> extraProviders,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      ...extraProviders,
    ],
    child: Consumer<AccessibilityModeController>(
      builder: (context, accessibility, _) {
        final AppTheme tokens = accessibility.mode == AccessibilityMode.senior
            ? const SeniorModeTheme()
            : const AppTheme();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tokens.toThemeData(),
          home: home,
        );
      },
    ),
  );
}

// Flutter's test binding renders text with a boxed placeholder font by
// default (no real glyphs on a headless VPS with no bundled app fonts).
// Loading a real system font under the 'Roboto' family name — the one
// Material's default TextTheme requests — makes the golden screenshots
// human-readable instead of tofu boxes.
Future<void> _loadReadableFont() async {
  const candidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/lato/Lato-Regular.ttf',
  ];
  final path = candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => '',
  );
  if (path.isEmpty) return;
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.textScaleFactorTestValue = 1.0;

  setUpAll(_loadReadableFont);

  testWidgets('screenshot: onboarding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_themedApp(
      const OnboardingScreen(),
      controller: AccessibilityModeController(prefs),
      extraProviders: fullProviderSet(prefs: prefs),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/1_onboarding.png'),
    );
  });

  testWidgets('screenshot: home with wellness score', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final prefs = await SharedPreferences.getInstance();
    final summaryRepo = FakeDailySummaryRepository()
      ..summary = WellnessSummary.fromJson({
        'summary_date': '2026-09-27',
        'wellness_score': 82,
        'score_version': 1,
        'component_scores': {'sleep': 85, 'activity': 78},
        'explanation': [
          {'component': 'sleep', 'note': 'Good night of rest'}
        ],
      });

    await tester.pumpWidget(_themedApp(
      const Scaffold(body: HomeScreen(now: _fixedMorning)),
      controller: AccessibilityModeController(prefs),
      extraProviders: fullProviderSet(prefs: prefs, dailySummaryRepository: summaryRepo),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/2_home.png'),
    );
  });

  testWidgets('screenshot: quick add after logging water', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final prefs = await SharedPreferences.getInstance();
    final waterRepo = FakeWaterRepository();

    await tester.pumpWidget(_themedApp(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showQuickAddSheet(context),
            child: const Text('Open Quick Add'),
          ),
        ),
      ),
      controller: AccessibilityModeController(prefs),
      extraProviders: [
        Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
        Provider<WaterRepository>.value(value: waterRepo),
        Provider<NutritionRepository>.value(value: FakeNutritionRepository()),
        Provider<ActivityRepository>.value(value: FakeActivityRepository()),
        Provider<WeightRepository>.value(value: FakeWeightRepository()),
        Provider<SleepRepository>.value(value: FakeSleepRepository()),
        Provider<MetricSyncTrigger>.value(value: FakeSyncTrigger()),
      ],
    ));
    await tester.tap(find.text('Open Quick Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickAddWaterRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickEntrySaveButton')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/3_quick_action_logged.png'),
    );
  });

  testWidgets('screenshot: Senior Mode enabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final prefs = await SharedPreferences.getInstance();
    final controller = AccessibilityModeController(prefs);

    await tester.pumpWidget(_themedApp(
      const Scaffold(body: HomeScreen(now: _fixedMorning)),
      controller: controller,
      extraProviders: fullProviderSet(prefs: prefs),
    ));
    await tester.pumpAndSettle();

    controller.setMode(AccessibilityMode.senior);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/4_senior_mode.png'),
    );
  });

  tearDownAll(() {
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
