import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/data/local/sync_service.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/screens/quick_actions/quick_add_sheet.dart';

import 'support/fake_repositories.dart';

Widget _wrap({
  required FakeWaterRepository waterRepo,
  required FakeWeightRepository weightRepo,
  required FakeSleepRepository sleepRepo,
  required FakeActivityRepository activityRepo,
  MetricSyncTrigger? syncTrigger,
}) {
  return MultiProvider(
    providers: [
      Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
      Provider<WaterRepository>.value(value: waterRepo),
      Provider<NutritionRepository>.value(value: FakeNutritionRepository()),
      Provider<ActivityRepository>.value(value: activityRepo),
      Provider<WeightRepository>.value(value: weightRepo),
      Provider<SleepRepository>.value(value: sleepRepo),
      Provider<MetricSyncTrigger>.value(value: syncTrigger ?? FakeSyncTrigger()),
    ],
    child: MaterialApp(
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
  testWidgets(
    'opening Water does not log anything until the user enters a value '
    'and taps Save (regression: this sheet used to silently log a fixed '
    '250ml the instant the row was tapped)',
    (tester) async {
      final waterRepo = FakeWaterRepository();

      await tester.pumpWidget(_wrap(
        waterRepo: waterRepo,
        weightRepo: FakeWeightRepository(),
        sleepRepo: FakeSleepRepository(),
        activityRepo: FakeActivityRepository(),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(waterRepo.logged, isEmpty);

      await tester.tap(find.byKey(const Key('quickAddWaterRow')));
      await tester.pumpAndSettle();

      // Merely opening the entry sheet must not have logged anything yet.
      expect(waterRepo.logged, isEmpty);
      expect(find.byKey(const Key('quickEntryValueText')), findsOneWidget);
      expect(find.text('250'), findsOneWidget);

      // Adjust away from the default to prove the entered value (not a
      // fixed default) is what gets saved.
      await tester.tap(find.byKey(const Key('quickEntryIncrementButton')));
      await tester.tap(find.byKey(const Key('quickEntryIncrementButton')));
      await tester.pumpAndSettle();
      expect(find.text('350'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quickEntrySaveButton')));
      await tester.pumpAndSettle();

      expect(waterRepo.logged, hasLength(1));
      expect(waterRepo.logged.single.amountMl, 350);
      expect(find.byKey(const Key('quickAddStatus')), findsOneWidget);
      expect(find.textContaining('Water · 350 ml added'), findsOneWidget);
    },
  );

  testWidgets('cancelling the Water entry sheet logs nothing', (tester) async {
    final waterRepo = FakeWaterRepository();

    await tester.pumpWidget(_wrap(
      waterRepo: waterRepo,
      weightRepo: FakeWeightRepository(),
      sleepRepo: FakeSleepRepository(),
      activityRepo: FakeActivityRepository(),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickAddWaterRow')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quickEntryCancelButton')));
    await tester.pumpAndSettle();

    expect(waterRepo.logged, isEmpty);
  });

  testWidgets('Sleep entry uses hour+minute steppers and saves the combined value',
      (tester) async {
    final sleepRepo = FakeSleepRepository();

    await tester.pumpWidget(_wrap(
      waterRepo: FakeWaterRepository(),
      weightRepo: FakeWeightRepository(),
      sleepRepo: sleepRepo,
      activityRepo: FakeActivityRepository(),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickAddSleepRow')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byKey(const Key('sleepMinutesStepper')),
      matching: find.byIcon(Icons.keyboard_arrow_up),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quickEntrySaveButton')));
    await tester.pumpAndSettle();

    expect(sleepRepo.logged, hasLength(1));
    expect(sleepRepo.logged.single.hoursSlept, closeTo(7.5 + 5 / 60, 0.001));
  });

  testWidgets(
    'rows disable while a write is still syncing, and a tap during that '
    'window does not log a second record (regression: the row became '
    'tappable again the instant the entry sheet closed, while the '
    'repository write + sync was still in flight)',
    (tester) async {
      final waterRepo = FakeWaterRepository();
      final syncTrigger = FakeSyncTrigger()..delay = const Duration(milliseconds: 200);

      await tester.pumpWidget(_wrap(
        waterRepo: waterRepo,
        weightRepo: FakeWeightRepository(),
        sleepRepo: FakeSleepRepository(),
        activityRepo: FakeActivityRepository(),
        syncTrigger: syncTrigger,
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quickAddWaterRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quickEntrySaveButton')));

      // The entry sheet has closed and the write+sync is now in flight
      // (still "syncing" for another ~200ms) -- the row must already be
      // disabled at this point, before the first write even settles.
      await tester.pump();
      final rowDuringSync =
          tester.widget<ListTile>(find.byKey(const Key('quickAddWaterRow')));
      expect(rowDuringSync.enabled, isFalse);

      // A tap on a disabled ListTile is a no-op, but assert on the
      // underlying state directly too: logging a second record during this
      // window would prove the guard isn't actually blocking the action.
      await tester.tap(find.byKey(const Key('quickAddWaterRow')));
      await tester.pump();
      expect(waterRepo.logged, hasLength(1));
      expect(syncTrigger.callCount, 1);

      await tester.pumpAndSettle();

      // Once the first write/sync fully settles, the row is tappable again.
      final rowAfterSync =
          tester.widget<ListTile>(find.byKey(const Key('quickAddWaterRow')));
      expect(rowAfterSync.enabled, isTrue);
      expect(waterRepo.logged, hasLength(1));
    },
  );
}
