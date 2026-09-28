import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/auth_repository.dart';
import 'package:bkknex_health_app/presentation/screens/auth/auth_gate.dart';
import 'package:bkknex_health_app/presentation/screens/auth/sign_in_screen.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('SignInScreen requires both fields before calling the repository',
      (tester) async {
    final authRepo = FakeAuthRepository()..setSignedIn(false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AuthRepository>.value(value: authRepo)],
        child: const MaterialApp(home: SignInScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('signInButton')));
    await tester.pump();

    expect(find.byKey(const Key('signInErrorMessage')), findsOneWidget);
    expect(authRepo.isSignedIn, isFalse);
  });

  testWidgets('SignInScreen signs in with email/password', (tester) async {
    final authRepo = FakeAuthRepository()..setSignedIn(false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AuthRepository>.value(value: authRepo)],
        child: const MaterialApp(home: SignInScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('signInEmailField')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signInPasswordField')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('signInButton')));
    await tester.pumpAndSettle();

    expect(authRepo.isSignedIn, isTrue);
  });

  testWidgets('AuthGate shows SignInScreen when signed out, HomeShell when signed in',
      (tester) async {
    final authRepo = FakeAuthRepository();
    final profileRepo = FakeProfileRepository()..displayName = 'Alex';
    authRepo.setSignedIn(false);

    await tester.pumpWidget(
      MultiProvider(
        providers: fullProviderSet(
          authRepository: authRepo,
          profileRepository: profileRepo,
        ),
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);

    authRepo.setSignedIn(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('navHome')), findsOneWidget);
  });
}
