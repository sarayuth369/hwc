import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/presentation/screens/health_report/health_report_reader_screen.dart';

import 'support/fake_image_picker.dart';
import 'support/fake_repositories.dart';

Widget _wrap(FakeAiRepository aiRepository) {
  return MultiProvider(
    providers: [
      Provider<AiRepository>.value(value: aiRepository),
    ],
    child: const MaterialApp(home: HealthReportReaderScreen()),
  );
}

void main() {
  testWidgets('shows the disclaimer before any photo is picked', (tester) async {
    await tester.pumpWidget(_wrap(FakeAiRepository()));

    expect(find.byKey(const Key('healthReportDisclaimer')), findsOneWidget);
    expect(
      find.textContaining('not a certified'),
      findsOneWidget,
    );
  });

  group('real photo capture -> two-step AI read', () {
    late FakeImagePickerPlatform fakePicker;

    setUp(() {
      fakePicker = FakeImagePickerPlatform();
      ImagePickerPlatform.instance = fakePicker;
    });

    testWidgets(
        'picking a photo transcribes it via vision, then analyzes the '
        'transcription via chat into a structured, separated '
        'facts-vs-interpretation result', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()
        ..imageResponse = {'description': 'Lab result: Glucose 95 mg/dL.'}
        ..chatResponse = {
          'reply': '{"summary": "Basic metabolic panel", '
              '"extracted_values": ["Glucose: 95 mg/dL"], '
              '"observations": ["Glucose is within the commonly cited normal '
              'fasting range."], '
              '"explanation": "Glucose measures blood sugar; this general '
              'reading is often considered typical for a fasting test.", '
              '"suggestions": ["Maintain regular meal timing."], '
              '"questions_for_provider": ["Was this fasting or non-fasting?"], '
              '"confidence": "medium"}',
          'conversationId': 'c1',
        };

      await tester.pumpWidget(_wrap(aiRepository));
      await tester.tap(find.byKey(const Key('healthReportUploadButton')));
      await tester.pumpAndSettle();

      expect(fakePicker.pickCount, 1);
      expect(aiRepository.lastImageRequest?['purpose'], 'document');
      expect(
        aiRepository.lastChatRequest?['message'],
        contains('Glucose 95 mg/dL'),
      );
      expect(find.byKey(const Key('healthReportAnalysisCard')), findsOneWidget);
      expect(find.text('Basic metabolic panel'), findsOneWidget);
      expect(find.text('• Glucose: 95 mg/dL'), findsOneWidget);
      expect(
        find.byKey(const Key('healthReportExplanationText')),
        findsOneWidget,
      );
      expect(find.text('medium confidence'), findsOneWidget);
    });

    testWidgets('a vision failure shows a plain error and never calls chat',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()..failure = const AiTimeoutFailure();

      await tester.pumpWidget(_wrap(aiRepository));
      await tester.tap(find.byKey(const Key('healthReportUploadButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('healthReportErrorMessage')), findsOneWidget);
      expect(find.text('That took too long. Please try again.'), findsOneWidget);
      expect(aiRepository.chatCallCount, 0);
    });

    testWidgets(
        'a malformed analysis reply (not valid JSON) falls back to the raw '
        'vision transcription instead of crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()
        ..imageResponse = {'description': 'Some handwritten notes.'}
        ..chatResponse = {'reply': 'Sorry, {not valid json', 'conversationId': 'c1'};

      await tester.pumpWidget(_wrap(aiRepository));
      await tester.tap(find.byKey(const Key('healthReportUploadButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('healthReportAnalysisCard')), findsNothing);
      expect(find.byKey(const Key('healthReportResultText')), findsOneWidget);
      expect(find.text('Some handwritten notes.'), findsOneWidget);
    });
  });
}
