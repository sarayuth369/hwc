import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/presentation/screens/health_report/health_report_reader_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('shows the disclaimer before any photo is picked', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiRepository>.value(value: FakeAiRepository()),
        ],
        child: const MaterialApp(home: HealthReportReaderScreen()),
      ),
    );

    expect(find.byKey(const Key('healthReportDisclaimer')), findsOneWidget);
    expect(
      find.textContaining('not a certified'),
      findsOneWidget,
    );
  });
}
