import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/auth_repository.dart';
import 'package:bkknex_health_app/presentation/screens/auth/sign_up_screen.dart';

import 'support/fake_repositories.dart';

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('signUpEmailField')),
    'new@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('signUpPasswordField')),
    'password123',
  );
  await tester.enterText(
    find.byKey(const Key('signUpConfirmPasswordField')),
    'password123',
  );
}

void main() {
  testWidgets(
    'an immediate session (no confirmation required) pops the screen '
    'itself rather than leaving Create Account on top of the real '
    'post-signup screen (regression: this is the exact bug that made '
    'signup look stuck)',
    (tester) async {
      final authRepo = FakeAuthRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<AuthRepository>.value(value: authRepo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('signUpButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsNothing);
    },
  );

  testWidgets(
    'confirmation-required signup shows the check-email state, then '
    'auto-dismisses itself the moment a session appears -- without the '
    'user having to tap "Back to sign in" (regression: this is the '
    'friction the one-shot-3 prompt reported as the remaining bug)',
    (tester) async {
      final authRepo = FakeAuthRepository()
        ..requiresConfirmation = true
        ..setSignedIn(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<AuthRepository>.value(value: authRepo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('signUpButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signUpInfoMessage')), findsOneWidget);
      expect(find.byType(SignUpScreen), findsOneWidget);

      // Simulate the user tapping the emailed confirmation link -- the
      // deep link resumes the app and Supabase fires a real session.
      authRepo.setSignedIn(true);
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsNothing);
    },
  );
}
