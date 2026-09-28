import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/presentation/screens/food_scanner/food_scanner_screen.dart';

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

    expect(nutritionRepository.logged, hasLength(1));
    expect(nutritionRepository.logged.single.description, 'Grilled chicken bowl');
    expect(find.byKey(const Key('foodScannerSaveMessage')), findsOneWidget);
  });
}
