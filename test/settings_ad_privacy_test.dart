import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/theme/app_theme_mode_controller.dart';
import 'package:bkknex_health_app/data/local/null_ad_service.dart';
import 'package:bkknex_health_app/presentation/screens/settings/settings_screen.dart';

import 'support/fake_repositories.dart';

class _PrivacyAdService extends NullAdService {
  _PrivacyAdService({required this.required});

  final bool required;
  int privacyFormOpened = 0;

  @override
  Future<bool> isPrivacyOptionsRequired() async => required;

  @override
  Future<void> showPrivacyOptions() async => privacyFormOpened++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSettings(WidgetTester tester, _PrivacyAdService adService) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AccessibilityModeController(prefs)),
          ChangeNotifierProvider(create: (_) => AppThemeModeController(prefs)),
          ...fullProviderSet(prefs: prefs, adService: adService),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('always discloses that free accounts may see Google ads', (tester) async {
    await pumpSettings(tester, _PrivacyAdService(required: false));
    expect(find.byKey(const Key('adsDisclosureTile')), findsOneWidget);
    expect(find.textContaining('Google Mobile Ads'), findsOneWidget);
    expect(find.textContaining('never health advice'), findsOneWidget);
  });

  testWidgets('hides "Ad privacy choices" when Google does not require it', (tester) async {
    await pumpSettings(tester, _PrivacyAdService(required: false));
    expect(find.byKey(const Key('adPrivacyChoicesTile')), findsNothing);
  });

  testWidgets('shows "Ad privacy choices" when required, and tapping opens the form', (tester) async {
    final ads = _PrivacyAdService(required: true);
    await pumpSettings(tester, ads);
    expect(find.byKey(const Key('adPrivacyChoicesTile')), findsOneWidget);

    await tester.tap(find.byKey(const Key('adPrivacyChoicesTile')));
    await tester.pumpAndSettle();
    expect(ads.privacyFormOpened, 1);
  });
}
