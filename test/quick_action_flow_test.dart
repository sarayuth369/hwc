import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/screens/quick_actions/quick_add_sheet.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('logging water via Quick Add queues the record', (tester) async {
    final waterRepo = FakeWaterRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
          Provider<WaterRepository>.value(value: waterRepo),
          Provider<NutritionRepository>.value(value: FakeNutritionRepository()),
          Provider<ActivityRepository>.value(value: FakeActivityRepository()),
          Provider<WeightRepository>.value(value: FakeWeightRepository()),
          Provider<SleepRepository>.value(value: FakeSleepRepository()),
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
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(waterRepo.logged, isEmpty);

    await tester.tap(find.byKey(const Key('quickAddWaterRow')));
    await tester.pumpAndSettle();

    expect(waterRepo.logged, hasLength(1));
    expect(waterRepo.logged.single.amountMl, 250);
    expect(find.byKey(const Key('quickAddStatus')), findsOneWidget);
    expect(find.textContaining('Logged 250ml'), findsOneWidget);
  });
}
