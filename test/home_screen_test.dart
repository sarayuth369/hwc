import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/presentation/screens/home/home_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home renders the Wellness Score from the summary repository',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
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
        providers: fullProviderSet(prefs: prefs, dailySummaryRepository: summaryRepo),
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wellnessScoreValue')), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('GOOD'), findsOneWidget);
  });

  testWidgets(
    'a real 0 score with an empty componentScores map shows the neutral '
    '"build your baseline" state, never NEEDS CARE (regression: nothing '
    'logged must not look like an alarming real bad day)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final summaryRepo = FakeDailySummaryRepository()
        ..summary = WellnessSummary.fromJson({
          'summary_date': '2026-09-26',
          'wellness_score': 0,
          'score_version': 1,
          'component_scores': {},
          'explanation': [],
        });

      await tester.pumpWidget(
        MultiProvider(
          providers: fullProviderSet(prefs: prefs, dailySummaryRepository: summaryRepo),
          child: const MaterialApp(home: Scaffold(body: HomeScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wellnessScoreNeutralState')), findsOneWidget);
      expect(find.text('NEEDS CARE'), findsNothing);
      expect(find.byKey(const Key('wellnessScoreValue')), findsNothing);
    },
  );

  testWidgets(
    'a 0 score with an all-zero (not empty) componentScores map still shows '
    'the neutral state (regression: real-device evidence showed the RPC '
    'returning zeroed-out keys rather than an omitted map for a brand-new '
    'account, which the earlier empty-map-only check missed)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final summaryRepo = FakeDailySummaryRepository()
        ..summary = WellnessSummary.fromJson({
          'summary_date': '2026-09-26',
          'wellness_score': 0,
          'score_version': 1,
          'component_scores': {'sleep': 0, 'activity': 0, 'water': 0, 'nutrition': 0},
          'explanation': [],
        });

      await tester.pumpWidget(
        MultiProvider(
          providers: fullProviderSet(prefs: prefs, dailySummaryRepository: summaryRepo),
          child: const MaterialApp(home: Scaffold(body: HomeScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wellnessScoreNeutralState')), findsOneWidget);
      expect(find.text('NEEDS CARE'), findsNothing);
      expect(find.byKey(const Key('wellnessScoreValue')), findsNothing);
    },
  );

  testWidgets(
    'a real low score backed by actual logged metrics still shows NEEDS '
    'CARE (regression guard: the neutral-state fix must not hide a '
    'genuinely bad real day)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final summaryRepo = FakeDailySummaryRepository()
        ..summary = WellnessSummary.fromJson({
          'summary_date': '2026-09-26',
          'wellness_score': 20,
          'score_version': 1,
          'component_scores': {'activity': 0, 'water': 0},
          'explanation': [],
        });

      await tester.pumpWidget(
        MultiProvider(
          providers: fullProviderSet(prefs: prefs, dailySummaryRepository: summaryRepo),
          child: const MaterialApp(home: Scaffold(body: HomeScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEEDS CARE'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.byKey(const Key('wellnessScoreNeutralState')), findsNothing);
    },
  );
}
