import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/presentation/widgets/ai_insight_card.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('AiInsightCard calls insight() and shows the reply',
      (tester) async {
    final aiRepository = FakeAiRepository()
      ..chatResponse = {'insight': 'You slept well — keep it up today.'};

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiRepository>.value(value: aiRepository),
          Provider<ProfileRepository>.value(value: FakeProfileRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: AiInsightCard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aiInsightText')), findsOneWidget);
    expect(find.text('You slept well — keep it up today.'), findsOneWidget);
  });
}
