import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/domain/models/accessibility_mode.dart';
import 'package:bkknex_health_app/presentation/widgets/senior_mode_toggle.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('toggling Senior Mode updates the shared controller',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AccessibilityModeController(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: SeniorModeToggle())),
      ),
    );

    expect(controller.mode, AccessibilityMode.normal);

    await tester.tap(find.byKey(const Key('seniorModeSwitch')));
    await tester.pumpAndSettle();

    expect(find.text('Turn on Senior Mode?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(controller.mode, AccessibilityMode.senior);
  });
}
