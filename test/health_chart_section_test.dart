import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/models/water_record.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/widgets/health_chart_section.dart';

import 'support/fake_repositories.dart';

Widget _wrap({
  required FakeWaterRepository waterRepo,
}) {
  return MultiProvider(
    providers: [
      Provider<SleepRepository>.value(value: FakeSleepRepository()),
      Provider<ActivityRepository>.value(value: FakeActivityRepository()),
      Provider<WaterRepository>.value(value: waterRepo),
      Provider<NutritionRepository>.value(value: FakeNutritionRepository()),
      Provider<WeightRepository>.value(value: FakeWeightRepository()),
    ],
    child: const MaterialApp(home: Scaffold(body: HealthChartSection())),
  );
}

void main() {
  testWidgets('with no data at all, every metric shows the honest empty state',
      (tester) async {
    await tester.pumpWidget(_wrap(waterRepo: FakeWaterRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('healthChartEmptyState')), findsOneWidget);
    expect(find.byKey(const Key('healthChartLatestValue')), findsNothing);
  });

  testWidgets(
    'a logged metric shows its latest value and the metric selector '
    'switches which series is displayed',
    (tester) async {
      final now = DateTime.now();
      final waterRepo = FakeWaterRepository()
        ..logged.addAll([
          WaterRecord(userId: 'u', loggedAt: now, amountMl: 500),
          WaterRecord(userId: 'u', loggedAt: now, amountMl: 250),
        ]);

      await tester.pumpWidget(_wrap(waterRepo: waterRepo));
      await tester.pumpAndSettle();

      // Water is selected by default only if it's the first chip tapped;
      // the widget defaults to Sleep, so switch to Water explicitly.
      await tester.tap(find.byKey(const Key('healthChartMetricwater')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('healthChartLatestValue')), findsOneWidget);
      // 500 + 250 ml summed for today = 0.75 L, shown to 1 decimal place.
      // RichText spans don't match the default plain-Text finder, so
      // search rendered rich text too.
      expect(
        find.textContaining('0.8 L', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('the 7-day/30-day toggle is present and switchable', (tester) async {
    await tester.pumpWidget(_wrap(waterRepo: FakeWaterRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('healthChartRangeToggle')), findsOneWidget);
    await tester.tap(find.text('30d'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
