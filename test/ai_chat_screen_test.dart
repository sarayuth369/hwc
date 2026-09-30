import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/data/local/chat_history_store.dart';
import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/presentation/screens/ai_chat/ai_chat_screen.dart';

import 'support/fake_repositories.dart';

Future<Widget> _wrap({
  required FakeCurrentUserService userService,
  required FakeAiRepository aiRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MultiProvider(
    providers: [
      Provider<CurrentUserService>.value(value: userService),
      Provider<AiRepository>.value(value: aiRepository),
      Provider<ProfileRepository>.value(value: FakeProfileRepository()),
      Provider<ChatHistoryStore>.value(value: ChatHistoryStore(prefs)),
    ],
    child: const MaterialApp(home: Scaffold(body: AiChatScreen())),
  );
}

void main() {
  testWidgets('shows sign-in message when signed out', (tester) async {
    final userService = FakeCurrentUserService()..currentUserId = null;
    await tester.pumpWidget(
      await _wrap(userService: userService, aiRepository: FakeAiRepository()),
    );

    expect(find.byKey(const Key('aiChatSignInMessage')), findsOneWidget);
    expect(find.byKey(const Key('aiChatSendButton')), findsNothing);
  });

  testWidgets('sending a message shows the reply', (tester) async {
    final aiRepository = FakeAiRepository()
      ..chatResponse = {'reply': 'Drink more water.', 'conversationId': 'c1'}
      ..delay = const Duration(milliseconds: 50);

    await tester.pumpWidget(
      await _wrap(
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
      await _wrap(
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
      await _wrap(
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

  testWidgets(
      'tapping the mic button attempts real on-device speech recognition '
      'and degrades honestly when no platform implementation is present '
      '(the same class of platform-plugin limitation documented for '
      'camera/notifications — flutter_test has no real Android runtime)',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(
        userService: FakeCurrentUserService(),
        aiRepository: FakeAiRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('aiChatVoiceButton')));
    // `speech_to_text`'s initialize() only ever completes via a native
    // status callback that never arrives here (no real platform channel
    // registered in a widget test) -- the screen's own 5s timeout is what
    // actually resolves it, not settling/frame-scheduling, so this has to
    // pump real time forward rather than use pumpAndSettle.
    await tester.pump(const Duration(seconds: 6));

    expect(find.byKey(const Key('aiChatVoiceErrorMessage')), findsOneWidget);
  });

  testWidgets('an AI reply shows a "read aloud" button, a user message does not',
      (tester) async {
    final aiRepository = FakeAiRepository()
      ..chatResponse = {'reply': 'Drink more water.', 'conversationId': 'c1'};

    await tester.pumpWidget(
      await _wrap(
        userService: FakeCurrentUserService(),
        aiRepository: aiRepository,
      ),
    );

    await tester.enterText(find.byKey(const Key('aiChatInput')), 'Hi');
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aiChatSpeakButton')), findsOneWidget);
  });
}
