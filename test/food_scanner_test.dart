import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/data/local/sync_service.dart';
import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/presentation/screens/food_scanner/food_scanner_screen.dart';

import 'support/fake_image_picker.dart';
import 'support/fake_repositories.dart';

Widget _wrap({
  required FakeAiRepository aiRepository,
  required FakeNutritionRepository nutritionRepository,
}) {
  return MultiProvider(
    providers: [
      Provider<AiRepository>.value(value: aiRepository),
      Provider<ProfileRepository>.value(value: FakeProfileRepository()),
      Provider<CurrentUserService>.value(value: FakeCurrentUserService()),
      Provider<NutritionRepository>.value(value: nutritionRepository),
      Provider<MetricSyncTrigger>.value(value: FakeSyncTrigger()),
    ],
    child: const MaterialApp(home: FoodScannerScreen()),
  );
}

void main() {
  // The photo-preview AspectRatio box is tall; the default 800x600 test
  // surface leaves the rest of the ListView outside its lazily built
  // viewport+cache extent. A taller surface (like a real phone) avoids
  // needing to scroll to reach the buttons below the photo.
  testWidgets('estimating without a description shows a plain error',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    await tester.pumpWidget(_wrap(
      aiRepository: FakeAiRepository(),
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pump();

    expect(find.byKey(const Key('foodScannerErrorMessage')), findsOneWidget);
  });

  testWidgets(
      'describing a meal calls the real AI chat endpoint and shows the estimate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final aiRepository = FakeAiRepository()
      ..chatResponse = {
        'reply': 'About 550 kcal: 35g protein, 40g carbs, 25g fat.',
        'conversationId': 'c1',
      };

    await tester.pumpWidget(_wrap(
      aiRepository: aiRepository,
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'Grilled chicken bowl',
    );
    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foodScannerEstimateText')), findsOneWidget);
    expect(find.textContaining('550 kcal'), findsOneWidget);
    expect(
      aiRepository.lastChatRequest?['message'],
      contains('Grilled chicken bowl'),
    );
  });

  testWidgets(
      'a transient provider failure is retried once automatically and '
      'still shows a result, without the user tapping anything',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final aiRepository = FakeAiRepository()
      ..chatFailuresBeforeSuccess = 1
      ..chatResponse = {
        'reply': '{"dish": "Fried rice", "confidence": "medium", '
            '"portion": "1 plate", "calories": 600, "protein_g": 18, '
            '"carbs_g": 75, "fat_g": 20, "notes": "Estimate."}',
        'conversationId': 'c1',
      };

    await tester.pumpWidget(_wrap(
      aiRepository: aiRepository,
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'Fried rice',
    );
    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pumpAndSettle();

    expect(aiRepository.chatCallCount, 2);
    expect(find.byKey(const Key('foodScannerErrorMessage')), findsNothing);
    expect(find.byKey(const Key('foodScannerStructuredEstimate')), findsOneWidget);
  });

  testWidgets(
      'a persistent provider failure (both attempts fail) shows the error '
      'with a working "Try again" button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final aiRepository = FakeAiRepository()..failure = const AiProviderFailure();

    await tester.pumpWidget(_wrap(
      aiRepository: aiRepository,
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'Fried rice',
    );
    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foodScannerErrorMessage')), findsOneWidget);
    expect(find.byKey(const Key('foodScannerRetryButton')), findsOneWidget);

    // Recover and retry -- the retry button must actually work, not just
    // be present.
    aiRepository
      ..failure = null
      ..chatResponse = {
        'reply': '{"dish": "Fried rice", "confidence": "low", '
            '"portion": "1 plate", "calories": 600, "protein_g": 18, '
            '"carbs_g": 75, "fat_g": 20, "notes": "Low confidence estimate."}',
        'conversationId': 'c1',
      };
    await tester.tap(find.byKey(const Key('foodScannerRetryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foodScannerStructuredEstimate')), findsOneWidget);
    expect(find.text('low confidence'), findsOneWidget);
  });

  testWidgets(
      'a structured JSON reply renders as labeled fields with a confidence badge',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final aiRepository = FakeAiRepository()
      ..chatResponse = {
        'reply': '{"dish": "Fried rice", "confidence": "medium", '
            '"portion": "1 plate, ~400g", "calories": 650, '
            '"protein_g": 20, "carbs_g": 80, "fat_g": 22, '
            '"notes": "Varies with oil and added protein."}',
        'conversationId': 'c1',
      };

    await tester.pumpWidget(_wrap(
      aiRepository: aiRepository,
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'American fried rice',
    );
    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foodScannerStructuredEstimate')), findsOneWidget);
    expect(find.byKey(const Key('foodScannerConfidenceBadge')), findsOneWidget);
    expect(find.text('medium confidence'), findsOneWidget);
    expect(find.text('650'), findsOneWidget);
    expect(find.byKey(const Key('foodScannerEstimateText')), findsNothing);
  });

  testWidgets(
      'a reply that is not valid JSON falls back to plain prose, never crashes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final aiRepository = FakeAiRepository()
      ..chatResponse = {
        'reply': 'Sorry, I could not estimate that confidently: {broken',
        'conversationId': 'c1',
      };

    await tester.pumpWidget(_wrap(
      aiRepository: aiRepository,
      nutritionRepository: FakeNutritionRepository(),
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'Mystery dish',
    );
    await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foodScannerStructuredEstimate')), findsNothing);
    expect(find.byKey(const Key('foodScannerEstimateText')), findsOneWidget);
  });

  testWidgets('Add to Today logs via the existing NutritionRepository',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    final nutritionRepository = FakeNutritionRepository();

    await tester.pumpWidget(_wrap(
      aiRepository: FakeAiRepository(),
      nutritionRepository: nutritionRepository,
    ));

    await tester.enterText(
      find.byKey(const Key('foodScannerDescriptionField')),
      'Grilled chicken bowl',
    );
    await tester.tap(find.byKey(const Key('foodScannerAddToTodayButton')));
    await tester.pumpAndSettle();

    // A confirmation dialog now sits between the button tap and the actual
    // save (the vision guess isn't always right — see HWC_DECISIONS.md).
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(nutritionRepository.logged, hasLength(1));
    expect(nutritionRepository.logged.single.description, 'Grilled chicken bowl');
    expect(find.byKey(const Key('foodScannerSaveMessage')), findsOneWidget);
  });

  group('real photo capture -> vision analysis', () {
    late FakeImagePickerPlatform fakePicker;

    setUp(() {
      fakePicker = FakeImagePickerPlatform();
      ImagePickerPlatform.instance = fakePicker;
    });

    testWidgets(
        'picking a photo calls the real vision endpoint and auto-fills the '
        'description field with its guess', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()
        ..imageResponse = {
          'description': 'A bowl of fried rice with a fried egg on top.',
        };

      await tester.pumpWidget(_wrap(
        aiRepository: aiRepository,
        nutritionRepository: FakeNutritionRepository(),
      ));

      await tester.tap(find.byKey(const Key('foodScannerGalleryButton')));
      await tester.pumpAndSettle();

      expect(fakePicker.pickCount, 1);
      expect(aiRepository.lastImageRequest?['purpose'], 'food');
      expect(
        (tester.widget(find.byKey(const Key('foodScannerDescriptionField')))
                as TextField)
            .controller
            ?.text,
        'A bowl of fried rice with a fried egg on top.',
      );
    });

    testWidgets(
        'a vision provider failure shows a plain error without crashing, '
        'and does not block manually describing the meal instead',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()..failure = const AiTimeoutFailure();

      await tester.pumpWidget(_wrap(
        aiRepository: aiRepository,
        nutritionRepository: FakeNutritionRepository(),
      ));

      await tester.tap(find.byKey(const Key('foodScannerGalleryButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foodScannerErrorMessage')), findsOneWidget);
      expect(find.text('That took too long. Please try again.'), findsOneWidget);

      // The vision failure must not leave the Estimate button permanently
      // disabled -- the user can still type a description and estimate.
      aiRepository.failure = null;
      aiRepository.chatResponse = {
        'reply': 'About 500 kcal.',
        'conversationId': 'c1',
      };
      await tester.enterText(
        find.byKey(const Key('foodScannerDescriptionField')),
        'Fried rice',
      );
      await tester.tap(find.byKey(const Key('foodScannerEstimateButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foodScannerEstimateText')), findsOneWidget);
    });

    testWidgets(
        'a malformed vision response (no description field) leaves the '
        'description field empty rather than fabricating text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()
        ..imageResponse = {'unexpected_field': 'nonsense'};

      await tester.pumpWidget(_wrap(
        aiRepository: aiRepository,
        nutritionRepository: FakeNutritionRepository(),
      ));

      await tester.tap(find.byKey(const Key('foodScannerGalleryButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foodScannerErrorMessage')), findsNothing);
      expect(
        (tester.widget(find.byKey(const Key('foodScannerDescriptionField')))
                as TextField)
            .controller
            ?.text,
        '',
      );
    });

    testWidgets(
        'the Estimate Nutrition button stays disabled while vision analysis '
        'is still running (regression: tapping it before the AI guess '
        'arrives used to show "Describe the meal first" even though a '
        'valid guess landed a moment later)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      final aiRepository = FakeAiRepository()..delay = const Duration(milliseconds: 50);

      await tester.pumpWidget(_wrap(
        aiRepository: aiRepository,
        nutritionRepository: FakeNutritionRepository(),
      ));

      await tester.tap(find.byKey(const Key('foodScannerGalleryButton')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('foodScannerEstimateButton')),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();
      final buttonAfter = tester.widget<FilledButton>(
        find.byKey(const Key('foodScannerEstimateButton')),
      );
      expect(buttonAfter.onPressed, isNotNull);
    });
  });
}
