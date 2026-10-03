import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/core/push/push_payload.dart';

void main() {
  group('PushPayload.tryParse (the stable contract)', () {
    test('accepts type + route + notification_id', () {
      final p = PushPayload.tryParse({'type': 'notification', 'route': 'health', 'notification_id': 'abc-123'});
      expect(p, isNotNull);
      expect(p!.route, PushRoute.health);
      expect(p.notificationId, 'abc-123');
    });

    test('every route maps to its HomeShell tab', () {
      const expected = {'home': 0, 'health': 1, 'ai_talk': 2, 'notifications': 3, 'profile': 4};
      expected.forEach((wire, tab) {
        final p = PushPayload.tryParse({'type': 'notification', 'route': wire});
        expect(p?.route.tabIndex, tab, reason: wire);
        expect(p?.route.wireName, wire);
      });
    });

    test('notification_id is optional', () {
      expect(PushPayload.tryParse({'type': 'notification', 'route': 'home'})?.notificationId, isNull);
    });

    test('rejects null, empty and wrong-typed payloads without throwing', () {
      expect(PushPayload.tryParse(null), isNull);
      expect(PushPayload.tryParse({}), isNull);
      expect(PushPayload.tryParse({'type': 'other', 'route': 'home'}), isNull);
      expect(PushPayload.tryParse({'type': 'notification'}), isNull);
      expect(PushPayload.tryParse({'type': 'notification', 'route': 5}), isNull);
      expect(PushPayload.tryParse({'type': 'notification', 'route': null}), isNull);
    });

    test('rejects unknown routes and anything URL-like (a push can only open known screens)', () {
      for (final bad in ['https://evil.example', 'javascript:alert(1)', 'Home', '../health', 'food_scanner', '']) {
        expect(PushPayload.tryParse({'type': 'notification', 'route': bad}), isNull, reason: bad);
      }
    });

    test('drops an oversized or non-string notification_id instead of trusting it', () {
      expect(PushPayload.tryParse({'type': 'notification', 'route': 'home', 'notification_id': 'x' * 100})?.notificationId, isNull);
      expect(PushPayload.tryParse({'type': 'notification', 'route': 'home', 'notification_id': 42})?.notificationId, isNull);
    });
  });

  test('maskPushToken never reveals a whole token', () {
    const token = 'dGVzdC1mY20tdG9rZW4tMDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5';
    final masked = maskPushToken(token);
    expect(masked, isNot(contains(token)));
    expect(masked.length, lessThan(15));
    expect(maskPushToken('short'), '***');
  });
}
