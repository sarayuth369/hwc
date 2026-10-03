import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/push/push_payload.dart';
import 'package:bkknex_health_app/data/push/fcm_push_service.dart';
import 'package:bkknex_health_app/domain/push/push_models.dart';

import 'support/fake_push.dart';
import 'support/fake_repositories.dart';

const _validData = {'type': 'notification', 'route': 'health', 'notification_id': 'n-1'};

void main() {
  late FakeFcmGateway gateway;
  late FakePushTokenRepository repo;
  late FakeLocalPushPresenter presenter;
  late FakeCurrentUserService user;
  late SharedPreferences prefs;
  late FcmPushService service;

  Future<void> build({bool initialize = true}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = FakeFcmGateway();
    repo = FakePushTokenRepository();
    presenter = FakeLocalPushPresenter();
    user = FakeCurrentUserService();
    service = FcmPushService(
      gateway: gateway,
      tokenRepository: repo,
      presenter: presenter,
      currentUser: user,
      prefs: prefs,
      appVersion: '9.9.9',
    );
    if (initialize) await service.initialize();
  }

  setUp(() => build());
  tearDown(() => service.dispose());

  group('Firebase initialization', () {
    test('failure disables push without throwing, and every call stays a safe no-op', () async {
      await build(initialize: false);
      gateway.initializeThrows = true;

      await service.initialize();
      expect(service.isAvailable, isFalse);

      await service.onSignedIn();
      await service.onSigningOut();
      expect(await service.enable(), PushPermissionStatus.denied);
      expect(await service.permissionStatus(), PushPermissionStatus.denied);
      expect(repo.registered, isEmpty);
      expect(repo.deactivated, isEmpty);
      expect(gateway.requestCalls, 0);
    });

    test('success makes push available and initialize is idempotent', () async {
      expect(service.isAvailable, isTrue);
      await service.initialize();
      expect(gateway.initializeCalls, 1);
    });

    test('a failing local presenter or launch-message read does not break startup', () async {
      await build(initialize: false);
      presenter.initializeThrows = true;
      gateway.initialMessageThrows = true;
      await service.initialize();
      expect(service.isAvailable, isTrue);
    });
  });

  group('permission abstraction', () {
    test('already granted: registers without prompting', () async {
      await service.onSignedIn();
      expect(gateway.requestCalls, 0);
      expect(repo.registered, hasLength(1));
    });

    test('not granted: asks exactly once, then registers if the user allows', () async {
      gateway.permission = PushPermissionStatus.denied;
      gateway.permissionAfterRequest = PushPermissionStatus.granted;
      await service.onSignedIn();
      expect(gateway.requestCalls, 1);
      expect(repo.registered, hasLength(1));
    });

    test('declined: no token is registered and the user is not nagged again', () async {
      gateway.permission = PushPermissionStatus.denied;
      gateway.permissionAfterRequest = PushPermissionStatus.denied;
      await service.onSignedIn();
      await service.onSignedIn();
      await service.onSignedIn();
      expect(gateway.requestCalls, 1);
      expect(repo.registered, isEmpty);
    });

    test('a permission prompt that throws is contained', () async {
      gateway.permission = PushPermissionStatus.denied;
      gateway.requestThrows = true;
      await service.onSignedIn();
      expect(repo.registered, isEmpty);
    });

    test('enable() (Settings) asks again on user request and registers when granted', () async {
      gateway.permission = PushPermissionStatus.denied;
      gateway.permissionAfterRequest = PushPermissionStatus.denied;
      await service.onSignedIn(); // auto prompt, declined
      expect(repo.registered, isEmpty);

      gateway.permissionAfterRequest = PushPermissionStatus.granted;
      expect(await service.enable(), PushPermissionStatus.granted);
      expect(repo.registered, hasLength(1));
    });

    test('enable() declined registers nothing', () async {
      gateway.permission = PushPermissionStatus.denied;
      gateway.permissionAfterRequest = PushPermissionStatus.denied;
      expect(await service.enable(), PushPermissionStatus.denied);
      expect(repo.registered, isEmpty);
    });
  });

  group('token registration', () {
    test('registers the token against the signed-in user with useful metadata', () async {
      await service.onSignedIn();
      final r = repo.registered.single;
      expect(r.token, gateway.token);
      expect(r.platform, 'android');
      expect(r.appVersion, '9.9.9');
      expect(r.deviceId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('the device id is stable across registrations and persisted', () async {
      await service.onSignedIn();
      gateway.refreshController.add('another-fcm-token-bbbbbbbbbbbbbbbbbbbbbbbb');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.registered, hasLength(2));
      expect(repo.registered[0].deviceId, repo.registered[1].deviceId);
      expect(prefs.getString('push_device_id_v1'), repo.registered.first.deviceId);
    });

    test('no token is registered for an anonymous (signed-out) user', () async {
      user.currentUserId = null;
      await service.onSignedIn();
      expect(repo.registered, isEmpty);
      expect(gateway.getTokenCalls, 0);
    });

    test('duplicate protection: the same token is not re-registered every resume', () async {
      await service.onSignedIn();
      await service.onSignedIn();
      await service.onSignedIn();
      expect(repo.registered, hasLength(1));
    });

    test('concurrent sign-in calls (shell mount + resume) coalesce into one registration', () async {
      await Future.wait([service.onSignedIn(), service.onSignedIn(), service.onSignedIn()]);
      expect(repo.registered, hasLength(1));
    });

    test('a null/empty token registers nothing', () async {
      gateway.token = null;
      await service.onSignedIn();
      gateway.token = '';
      await service.onSignedIn();
      expect(repo.registered, isEmpty);
    });

    test('backend unavailable: no crash, and the next sign-in/resume retries', () async {
      repo.registerThrows = true;
      await service.onSignedIn();
      expect(repo.registered, isEmpty);

      repo.registerThrows = false;
      await service.onSignedIn();
      expect(repo.registered, hasLength(1));
    });
  });

  group('token refresh', () {
    test('a refreshed token is registered for the signed-in user', () async {
      await service.onSignedIn();
      gateway.refreshController.add('refreshed-fcm-token-cccccccccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.registered.map((r) => r.token), [gateway.token, 'refreshed-fcm-token-cccccccccccccccccccccc']);
    });

    test('ignored when signed out', () async {
      await service.onSignedIn();
      user.currentUserId = null;
      gateway.refreshController.add('refreshed-fcm-token-cccccccccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.registered, hasLength(1));
    });

    test('ignored when notification permission is not granted', () async {
      await service.onSignedIn();
      gateway.permission = PushPermissionStatus.denied;
      gateway.refreshController.add('refreshed-fcm-token-cccccccccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.registered, hasLength(1));
    });
  });

  group('logout deactivation', () {
    test('deactivates this device token before sign-out', () async {
      await service.onSignedIn();
      await service.onSigningOut();
      expect(repo.deactivated, [gateway.token]);
    });

    test('after sign-out the same token registers again on the next sign-in (even for another user)', () async {
      await service.onSignedIn();
      await service.onSigningOut();
      await service.onSignedIn();
      expect(repo.registered, hasLength(2));
    });

    test('a failing deactivate never blocks sign-out', () async {
      await service.onSignedIn();
      repo.deactivateThrows = true;
      await service.onSigningOut();
      expect(repo.deactivated, isEmpty);
    });

    test('with no known token it does nothing', () async {
      gateway.token = null;
      await service.onSigningOut();
      expect(repo.deactivated, isEmpty);
    });
  });

  group('foreground messages', () {
    test('are shown (the OS would not show them) and tell the inbox to refresh', () async {
      var inboxEvents = 0;
      final sub = service.inboxChanged.listen((_) => inboxEvents++);
      gateway.foregroundController.add(
        const PushMessage(messageId: 'm1', title: 'Hello', body: 'World', data: _validData),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(presenter.shown, hasLength(1));
      expect(presenter.shown.single.$1.title, 'Hello');
      expect(presenter.shown.single.$2?.route, PushRoute.health);
      expect(inboxEvents, 1);
    });

    test('the same message delivered twice is shown once', () async {
      const m = PushMessage(messageId: 'dup', title: 'T', body: 'B', data: _validData);
      gateway.foregroundController
        ..add(m)
        ..add(m);
      await Future<void>.delayed(Duration.zero);
      expect(presenter.shown, hasLength(1));
    });

    test('a malformed payload is still shown as plain text but carries no route; nothing crashes', () async {
      gateway.foregroundController.add(
        const PushMessage(messageId: 'bad', title: 'T', body: 'B', data: {'route': 'https://evil.example', 'type': 'x'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(presenter.shown.single.$2, isNull);
    });

    test('a presenter that throws does not break message handling', () async {
      presenter.showThrows = true;
      gateway.foregroundController.add(const PushMessage(messageId: 'x', title: 'T', body: 'B', data: _validData));
      await Future<void>.delayed(Duration.zero);
      gateway.foregroundController.add(const PushMessage(messageId: 'y', title: 'T', body: 'B', data: _validData));
      await Future<void>.delayed(Duration.zero);
      expect(service.isAvailable, isTrue);
    });
  });

  group('notification tap routing', () {
    test('a tap with a valid payload requests that route', () async {
      final routes = <PushRoute>[];
      final sub = service.routeRequests.listen(routes.add);
      gateway.openedController.add(const PushMessage(messageId: 'o1', data: _validData));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(routes, [PushRoute.health]);
    });

    test('malformed / unknown payloads never navigate or crash', () async {
      final routes = <PushRoute>[];
      final sub = service.routeRequests.listen(routes.add);
      for (final data in <Map<String, dynamic>>[
        {},
        {'type': 'notification'},
        {'type': 'notification', 'route': 'https://evil.example'},
        {'type': 'notification', 'route': 42},
        {'type': 'other', 'route': 'home'},
      ]) {
        gateway.openedController.add(PushMessage(data: data));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(routes, isEmpty);
    });

    test('the same tap reported twice navigates once (no duplicate navigation)', () async {
      final routes = <PushRoute>[];
      final sub = service.routeRequests.listen(routes.add);
      const m = PushMessage(messageId: 'same', data: _validData);
      gateway.openedController
        ..add(m)
        ..add(m);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(routes, hasLength(1));
    });

    test('a tap on a foreground-shown (local) notification routes too', () async {
      final routes = <PushRoute>[];
      final sub = service.routeRequests.listen(routes.add);
      presenter.tapController.add(const PushPayload(route: PushRoute.aiTalk, notificationId: 'n'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(routes, [PushRoute.aiTalk]);
    });

    test('cold start: the launching tap is parked until the shell asks for it, exactly once', () async {
      await build(initialize: false);
      gateway.initialMessage = const PushMessage(messageId: 'cold', data: _validData);
      await service.initialize();

      expect(service.takePendingRoute(), PushRoute.health);
      expect(service.takePendingRoute(), isNull);
    });

    test('cold start tap is not also replayed when the same message arrives via onMessageOpenedApp', () async {
      await build(initialize: false);
      const m = PushMessage(messageId: 'cold2', data: _validData);
      gateway.initialMessage = m;
      await service.initialize();
      expect(service.takePendingRoute(), PushRoute.health);

      final routes = <PushRoute>[];
      final sub = service.routeRequests.listen(routes.add);
      gateway.openedController.add(m);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(routes, isEmpty);
    });

    test('a malformed launch message leaves nothing pending', () async {
      await build(initialize: false);
      gateway.initialMessage = const PushMessage(messageId: 'cold3', data: {'type': 'x'});
      await service.initialize();
      expect(service.takePendingRoute(), isNull);
    });
  });
}
