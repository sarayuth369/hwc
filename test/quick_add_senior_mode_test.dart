import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/theme/senior_mode_theme.dart';
import 'package:bkknex_health_app/data/local/sync_service.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/screens/quick_actions/quick_add_sheet.dart';

import 'support/fake_repositories.dart';

Widget _wrap() {
  return MultiProvider(
    providers: [
      Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
      Provider<WaterRepository>.value(value: FakeWaterRepository()),
      Provider<NutritionRepository>.value(value: FakeNutritionRepository()),
      Provider<ActivityRepository>.value(value: FakeActivityRepository()),
      Provider<WeightRepository>.value(value: FakeWeightRepository()),
      Provider<SleepRepository>.value(value: FakeSleepRepository()),
      Provider<MetricSyncTrigger>.value(value: FakeSyncTrigger()),
    ],
    child: MaterialApp(
      theme: const SeniorModeTheme().toThemeData(),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showQuickAddSheet(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Quick Add\'s 6-row list does not overflow under Senior Mode '
    '(regression: 64px min touch targets + a larger type scale made the '
    'row list taller than a common phone screen, found via this exact test)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quickAddSleepRow')), findsOneWidget);
    },
  );

  testWidgets('the numeric entry sheet itself does not overflow under Senior Mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quickAddWaterRow')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quickEntrySaveButton')), findsOneWidget);
  });

  testWidgets('the Sleep entry sheet itself does not overflow under Senior Mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quickAddSleepRow')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sleepHoursStepper')), findsOneWidget);
  });
}
