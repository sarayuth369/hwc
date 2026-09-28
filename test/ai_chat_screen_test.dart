import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/presentation/screens/ai_chat/ai_chat_screen.dart';

import 'support/fake_repositories.dart';

Widget _wrap({
  required FakeCurrentUserService userService,
  required FakeAiRepository aiRepository,
}) {
  return MultiProvider(
    providers: [
      Provider<CurrentUserService>.value(value: userService),
      Provider<AiRepository>.value(value: aiRepository),
      Provider<ProfileRepository>.value(value: FakeProfileRepository()),
    ],
    child: const MaterialApp(home: Scaffold(body: AiChatScreen())),
  );
}

void main() {
  testWidgets('shows sign-in message when signed out', (tester) async {
    final userService = FakeCurrentUserService()..currentUserId = null;
    await tester.pumpWidget(
      _wrap(userService: userService, aiRepository: FakeAiRepository()),
    );

    expect(find.byKey(const Key('aiChatSignInMessage')), findsOneWidget);
    expect(find.byKey(const Key('aiChatSendButton')), findsNothing);
  });

  testWidgets('sending a message shows the reply', (tester) async {
    final aiRepository = FakeAiRepository()
      ..chatResponse = {'reply': 'Drink more water.', 'conversationId': 'c1'}
      ..delay = const Duration(milliseconds: 50);

    await tester.pumpWidget(
      _wrap(
        userService: FakeCurrentUserService(),
        aiRepository: aiRepository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('aiChatInput')),
      'How much water should I drink?',
    );
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aiChatReply')), findsOneWidget);
    expect(find.text('Drink more water.'), findsOneWidget);
    expect(aiRepository.lastChatRequest?['message'],
        'How much water should I drink?');
  });

  testWidgets('shows the professional-care notice when flagged',
      (tester) async {
    final aiRepository = FakeAiRepository()
      ..chatResponse = {
        'reply': 'Please seek care.',
        'conversationId': 'c1',
        'safetyFlag': {'flagged': true, 'requiresProfessionalCare': true},
      };

    await tester.pumpWidget(
      _wrap(
        userService: FakeCurrentUserService(),
        aiRepository: aiRepository,
      ),
    );

    await tester.enterText(find.byKey(const Key('aiChatInput')), 'help');
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('aiChatProfessionalCareNotice')),
      findsOneWidget,
    );
  });

  testWidgets('shows an error and retries on failure', (tester) async {
    final aiRepository = FakeAiRepository()..failure = const AiNetworkFailure();

    await tester.pumpWidget(
      _wrap(
        userService: FakeCurrentUserService(),
        aiRepository: aiRepository,
      ),
    );

    await tester.enterText(find.byKey(const Key('aiChatInput')), 'hi');
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aiChatErrorMessage')), findsOneWidget);
    expect(
      find.text('Could not reach AI. Check your connection and try again.'),
      findsOneWidget,
    );

    aiRepository.failure = null;
    aiRepository.chatResponse = {'reply': 'ok now', 'conversationId': 'c1'};
    await tester.tap(find.byKey(const Key('aiChatRetryButton')));
    await tester.pumpAndSettle();

    expect(find.text('ok now'), findsOneWidget);
  });
}
