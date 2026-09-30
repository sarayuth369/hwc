import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/daily_summary_repository.dart';
import 'package:bkknex_health_app/presentation/widgets/wellness_score_card.dart';
import 'package:bkknex_health_app/presentation/widgets/wellness_trend_section.dart';

import 'support/fake_repositories.dart';

WellnessSummary _summary({
  required String date,
  int? score,
  Map<String, dynamic> componentScores = const {},
}) =>
    WellnessSummary.fromJson({
      'summary_date': date,
      'wellness_score': score,
      'score_version': 1,
      'component_scores': componentScores,
      'explanation': [],
    });

void main() {
  testWidgets(
    'a week with no real data shows one plain-language empty state, not '
    'seven unexplained dashes (regression: a row of technically-honest '
    'dashes still reads as "broken" to a user)',
    (tester) async {
      final repo = FakeDailySummaryRepository()
        ..trend = List.generate(
          7,
          (i) => _summary(
            date: '2026-01-0${i + 1}',
            score: 0,
            componentScores: const {'sleep': 0, 'activity': 0},
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<DailySummaryRepository>.value(
              value: repo,
              child: const WellnessTrendSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wellnessTrendEmptyState')), findsOneWidget);
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('a real score explains what it means and which metrics fed it',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WellnessScoreCard(
            summary: _summary(
              date: '2026-01-01',
              score: 43,
              componentScores: const {'sleep': 40, 'activity': 46},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wellnessScoreMeaning')), findsOneWidget);
    expect(find.byKey(const Key('wellnessScoreContributors')), findsOneWidget);
    expect(find.textContaining('Sleep and Activity'), findsOneWidget);
  });
}
