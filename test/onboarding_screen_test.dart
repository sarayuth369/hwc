import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/theme/app_theme_mode_controller.dart';
import 'package:bkknex_health_app/presentation/screens/onboarding/onboarding_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding collects a name and continues to the Home shell',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final profileRepo = FakeProfileRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AccessibilityModeController(prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => AppThemeModeController(prefs),
          ),
          ...fullProviderSet(prefs: prefs, profileRepository: profileRepo),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    expect(find.text("Let's get set up"), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboardingNameField')),
      'Alex',
    );
    await tester.tap(find.byKey(const Key('onboardingContinueButton')));
    await tester.pumpAndSettle();

    expect(profileRepo.displayName, 'Alex');
    expect(find.byKey(const Key('navHome')), findsOneWidget);
  });
}
