import 'dart:convert';
import 'dart:io';

import 'package:bkknex_health_app/data/ai/http_ai_repository.dart';
import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_repositories.dart';

void main() {
  group('HttpAiRepository', () {
    test('throws AiAuthFailure without a network call when signed out', () async {
      final userService = FakeCurrentUserService()..accessToken = null;
      var called = false;
      final repository = HttpAiRepository(
        currentUserService: userService,
        client: MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        () => repository.chat({'message': 'hi', 'healthContext': {}}),
        throwsA(isA<AiAuthFailure>()),
      );
      expect(called, isFalse);
    });

    test('sends the Bearer token and returns the decoded reply', () async {
      final userService = FakeCurrentUserService()..accessToken = 'tok123';
      http.Request? sentRequest;
      final repository = HttpAiRepository(
        currentUserService: userService,
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            jsonEncode({'reply': 'hello', 'conversationId': 'c1'}),
            200,
          );
        }),
      );

      final result =
          await repository.chat({'message': 'hi', 'healthContext': {}});

      expect(result['reply'], 'hello');
      expect(sentRequest?.headers['Authorization'], 'Bearer tok123');
      expect(
        sentRequest?.url.toString(),
        contains('/api/ai/chat'),
      );
    });

    test('throws AiAuthFailure on a 401 response', () async {
      final userService = FakeCurrentUserService()..accessToken = 'tok123';
      final repository = HttpAiRepository(
        currentUserService: userService,
        client: MockClient((request) async => http.Response(
              jsonEncode({'error': 'auth', 'code': 'auth_failed'}),
              401,
            )),
      );

      await expectLater(
        () => repository.chat({'message': 'hi', 'healthContext': {}}),
        throwsA(isA<AiAuthFailure>()),
      );
    });

    test('throws AiProviderFailure on a 503 response', () async {
      final userService = FakeCurrentUserService()..accessToken = 'tok123';
      final repository = HttpAiRepository(
        currentUserService: userService,
        client: MockClient((request) async => http.Response(
              jsonEncode({'error': 'down', 'code': 'provider_error'}),
              503,
            )),
      );

      await expectLater(
        () => repository.chat({'message': 'hi', 'healthContext': {}}),
        throwsA(isA<AiProviderFailure>()),
      );
    });

    test('throws AiNetworkFailure when the client throws SocketException',
        () async {
      final userService = FakeCurrentUserService()..accessToken = 'tok123';
      final repository = HttpAiRepository(
        currentUserService: userService,
        client: MockClient((request) async {
          throw const SocketException('no route');
        }),
      );

      await expectLater(
        () => repository.chat({'message': 'hi', 'healthContext': {}}),
        throwsA(isA<AiNetworkFailure>()),
      );
    });
  });
}
