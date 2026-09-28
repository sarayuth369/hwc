import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/daily_summary_repository.dart';
import 'package:bkknex_health_app/presentation/screens/home/home_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('Home renders the Wellness Score from the summary repository',
      (tester) async {
    final summaryRepo = FakeDailySummaryRepository()
      ..summary = WellnessSummary.fromJson({
        'summary_date': '2026-09-26',
        'wellness_score': 78,
        'score_version': 1,
        'component_scores': {'sleep': 80},
        'explanation': [
          {'component': 'sleep', 'note': 'Good night of rest'}
        ],
      });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DailySummaryRepository>.value(value: summaryRepo),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('78'), findsOneWidget);
    expect(find.text('Wellness Score'), findsOneWidget);
  });
}
