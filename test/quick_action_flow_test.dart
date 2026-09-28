import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/presentation/screens/quick_actions/quick_actions_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('logging water queues the record and refreshes the status',
      (tester) async {
    final waterRepo = FakeWaterRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
          Provider<WaterRepository>.value(value: waterRepo),
        ],
        child: const MaterialApp(home: QuickActionsScreen()),
      ),
    );

    expect(waterRepo.logged, isEmpty);

    await tester.tap(find.byKey(const Key('logWater250Button')));
    await tester.pumpAndSettle();

    expect(waterRepo.logged, hasLength(1));
    expect(waterRepo.logged.single.amountMl, 250);
    expect(find.byKey(const Key('quickActionStatus')), findsOneWidget);
    expect(find.textContaining('Logged 250ml'), findsOneWidget);
  });
}
