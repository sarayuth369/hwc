import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkknex_health_app/data/billing/http_entitlement_verifier.dart';
import 'package:bkknex_health_app/data/supabase/subscription_repository_impl.dart';
import 'package:bkknex_health_app/domain/billing/entitlement_verifier.dart';

import 'support/fake_repositories.dart';

Future<VerificationOutcome> _verify(
  http.Client client, {
  FakeCurrentUserService? user,
}) =>
    HttpEntitlementVerifier(
      currentUserService: user ?? FakeCurrentUserService(),
      client: client,
    ).verify(purchaseToken: 'purchase-token', productId: 'hwc_premium');

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('HttpEntitlementVerifier', () {
    test('sends the token and product to the Worker with the user\'s own bearer token', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _json(200, {'tier': 'premium', 'status': 'active'});
      });

      final outcome = await _verify(client);

      expect(outcome, VerificationOutcome.entitled);
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/billing/google-play/verify');
      expect(seen.headers['Authorization'], 'Bearer test-access-token');
      expect(jsonDecode(seen.body), {'purchaseToken': 'purchase-token', 'productId': 'hwc_premium'});
      // No premium flag is ever sent for the server to "accept".
      expect(seen.body.toLowerCase(), isNot(contains('"tier"')));
    });

    test('200 free/expired -> notEntitled', () async {
      final client = MockClient((_) async => _json(200, {'tier': 'free', 'status': 'expired'}));
      expect(await _verify(client), VerificationOutcome.notEntitled);
    });

    test('200 free/pending_provider -> pending', () async {
      final client =
          MockClient((_) async => _json(200, {'tier': 'free', 'status': 'pending_provider'}));
      expect(await _verify(client), VerificationOutcome.pending);
    });

    test('malformed 200 body -> unavailable (never entitled)', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      expect(await _verify(client), VerificationOutcome.unavailable);
    });

    test('401 -> unauthenticated', () async {
      final client = MockClient((_) async => _json(401, {'code': 'auth_failed'}));
      expect(await _verify(client), VerificationOutcome.unauthenticated);
    });

    test('403 (wrong account) and 422 (invalid) -> rejected', () async {
      for (final status in [403, 422]) {
        final client = MockClient((_) async => _json(status, {'code': 'x'}));
        expect(await _verify(client), VerificationOutcome.rejected, reason: '$status');
      }
    });

    test('503 billing_not_configured -> notConfigured; other 503 -> unavailable', () async {
      expect(
        await _verify(MockClient((_) async => _json(503, {'code': 'billing_not_configured'}))),
        VerificationOutcome.notConfigured,
      );
      expect(
        await _verify(MockClient((_) async => _json(503, {'code': 'something'}))),
        VerificationOutcome.unavailable,
      );
    });

    test('5xx / 502 -> unavailable', () async {
      for (final status in [500, 502, 504]) {
        expect(
          await _verify(MockClient((_) async => _json(status, {'code': 'x'}))),
          VerificationOutcome.unavailable,
          reason: '$status',
        );
      }
    });

    test('network failure -> unavailable (never entitled)', () async {
      final client = MockClient((_) async => throw http.ClientException('offline'));
      expect(await _verify(client), VerificationOutcome.unavailable);
    });

    test('no signed-in session -> unauthenticated without any request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return _json(200, {'tier': 'premium'});
      });
      final user = FakeCurrentUserService()..accessToken = null;
      expect(await _verify(client, user: user), VerificationOutcome.unauthenticated);
      expect(called, isFalse);
    });
  });

  group('SupabaseSubscriptionRepository.premiumUntil (what counts as Premium)', () {
    final now = DateTime.utc(2026, 10, 10);
    Map<String, dynamic> row(String tier, String status, String? end) =>
        {'tier': tier, 'status': status, 'current_period_end': end};

    test('active premium with a future period end grants access until that end', () {
      final until = SupabaseSubscriptionRepository.premiumUntil(
        row('premium', 'active', '2026-11-10T00:00:00Z'),
        now,
      );
      expect(until, DateTime.utc(2026, 11, 10));
    });

    test('a cancelled subscription keeps access until the paid period ends', () {
      expect(
        SupabaseSubscriptionRepository.premiumUntil(
          row('premium', 'cancelled', '2026-10-20T00:00:00Z'),
          now,
        ),
        isNotNull,
      );
    });

    test('a stale premium row past its period end grants nothing', () {
      expect(
        SupabaseSubscriptionRepository.premiumUntil(
          row('premium', 'active', '2026-10-01T00:00:00Z'),
          now,
        ),
        isNull,
      );
    });

    test('free tier, expired, pending, missing row or missing end never grant', () {
      expect(SupabaseSubscriptionRepository.premiumUntil(null, now), isNull);
      expect(
        SupabaseSubscriptionRepository.premiumUntil(row('free', 'none', null), now),
        isNull,
      );
      expect(
        SupabaseSubscriptionRepository.premiumUntil(
          row('premium', 'expired', '2026-11-10T00:00:00Z'),
          now,
        ),
        isNull,
      );
      expect(
        SupabaseSubscriptionRepository.premiumUntil(
          row('premium', 'pending_provider', '2026-11-10T00:00:00Z'),
          now,
        ),
        isNull,
      );
      expect(
        SupabaseSubscriptionRepository.premiumUntil(row('premium', 'active', null), now),
        isNull,
      );
      expect(
        SupabaseSubscriptionRepository.premiumUntil(row('premium', 'active', 'garbage'), now),
        isNull,
      );
    });
  });
}
