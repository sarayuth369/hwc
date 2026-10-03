import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/push/push_payload.dart';
import 'package:bkknex_health_app/core/theme/app_theme_mode_controller.dart';
import 'package:bkknex_health_app/domain/models/notification_item.dart';
import 'package:bkknex_health_app/domain/push/push_models.dart';
import 'package:bkknex_health_app/presentation/screens/home/home_shell.dart';
import 'package:bkknex_health_app/presentation/screens/profile/profile_screen.dart';
import 'package:bkknex_health_app/presentation/screens/settings/settings_screen.dart';

import 'support/fake_push.dart';
import 'support/fake_repositories.dart';

class _OrderedAuthRepository extends FakeAuthRepository {
  _OrderedAuthRepository(this.log);

  final List<String> log;

  @override
  Future<void> signOut() async {
    log.add('auth.signOut');
    await super.signOut();
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    required FakePushService push,
    FakeNotificationRepository? notifications,
    FakeAuthRepository? auth,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AccessibilityModeController(prefs)),
          ChangeNotifierProvider(create: (_) => AppThemeModeController(prefs)),
          ...fullProviderSet(
            prefs: prefs,
            pushService: push,
            notificationRepository: notifications,
            authRepository: auth,
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  group('HomeShell + push', () {
    testWidgets('registers this device for push once the signed-in shell is up', (tester) async {
      final push = FakePushService();
      await pump(tester, const HomeShell(), push: push);
      expect(push.events, contains('signedIn'));
    });

    testWidgets('a notification tap that launched the app (cold start) opens its tab', (tester) async {
      final push = FakePushService()..pending = PushRoute.notifications;
      await pump(tester, const HomeShell(), push: push);
      expect(selectedTab(tester), PushRoute.notifications.tabIndex);
      expect(push.takePendingRoute(), isNull, reason: 'consumed exactly once');
    });

    testWidgets('a tap while the app is running switches to the requested tab', (tester) async {
      final push = FakePushService();
      await pump(tester, const HomeShell(), push: push);
      expect(selectedTab(tester), 0);

      push.routeController.add(PushRoute.health);
      await tester.pumpAndSettle();
      expect(selectedTab(tester), PushRoute.health.tabIndex);
    });

    testWidgets('the same route requested twice does not stack navigation', (tester) async {
      final push = FakePushService();
      await pump(tester, const HomeShell(), push: push);
      push.routeController
        ..add(PushRoute.profile)
        ..add(PushRoute.profile);
      await tester.pumpAndSettle();
      expect(selectedTab(tester), PushRoute.profile.tabIndex);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('a tap pops any screen pushed above the shell before selecting the tab', (tester) async {
      final push = FakePushService();
      await pump(tester, const HomeShell(), push: push);
      final nav = Navigator.of(tester.element(find.byType(HomeShell)));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('PUSHED SCREEN'))));
      await tester.pumpAndSettle();
      expect(find.text('PUSHED SCREEN'), findsOneWidget);

      push.routeController.add(PushRoute.notifications);
      await tester.pumpAndSettle();
      expect(find.text('PUSHED SCREEN'), findsNothing);
      expect(selectedTab(tester), PushRoute.notifications.tabIndex);
    });

    testWidgets('a foreground push refreshes the Notifications tab so the new row appears', (tester) async {
      final push = FakePushService();
      final notifications = FakeNotificationRepository();
      await pump(tester, const HomeShell(), push: push, notifications: notifications);

      notifications.items.add(NotificationItem(
        id: 'new-1',
        category: NotificationCategory.admin,
        title: 'Fresh from the team',
        body: 'Body',
        createdAt: DateTime.now(),
      ));
      push.inboxController.add(null);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('navNotifications')));
      await tester.pumpAndSettle();
      expect(find.text('Fresh from the team'), findsOneWidget);
    });
  });

  group('sign-out', () {
    testWidgets('deactivates the push token BEFORE the session is signed out', (tester) async {
      final log = <String>[];
      final auth = _OrderedAuthRepository(log);
      final push = FakePushService(log: log);

      await pump(tester, const ProfileScreen(), push: push, auth: auth);
      log.clear(); // ignore the sign-in time registration
      await tester.ensureVisible(find.byKey(const Key('signOutButton')));
      await tester.tap(find.byKey(const Key('signOutButton')));
      await tester.pumpAndSettle();

      // The deactivate RPC needs the session, so it must run first.
      expect(log, ['signingOut', 'auth.signOut']);
    });
  });

  group('Settings push tile', () {
    testWidgets('hidden when push is unavailable (e.g. build without Firebase)', (tester) async {
      await pump(tester, const SettingsScreen(), push: FakePushService(available: false));
      expect(find.byKey(const Key('pushNotificationsTile')), findsNothing);
    });

    testWidgets('offers "Turn on" when off, and enabling flips it to on', (tester) async {
      final push = FakePushService()..permission = PushPermissionStatus.denied;
      await pump(tester, const SettingsScreen(), push: push);
      expect(find.byKey(const Key('pushNotificationsTile')), findsOneWidget);
      expect(find.byKey(const Key('enablePushButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('enablePushButton')));
      await tester.pumpAndSettle();
      expect(push.events, contains('enable'));
      expect(find.byKey(const Key('enablePushButton')), findsNothing);
      expect(find.textContaining('On —'), findsOneWidget);
    });

    testWidgets('if the user still declines, says so honestly instead of claiming it is on', (tester) async {
      final push = FakePushService()
        ..permission = PushPermissionStatus.denied
        ..enableResult = PushPermissionStatus.denied;
      await pump(tester, const SettingsScreen(), push: push);
      await tester.tap(find.byKey(const Key('enablePushButton')));
      await tester.pumpAndSettle();
      expect(find.textContaining('system settings'), findsOneWidget);
      expect(find.byKey(const Key('enablePushButton')), findsOneWidget);
    });

    testWidgets('shows On when permission is already granted', (tester) async {
      final push = FakePushService()..permission = PushPermissionStatus.granted;
      await pump(tester, const SettingsScreen(), push: push);
      expect(find.textContaining('On —'), findsOneWidget);
      expect(find.byKey(const Key('enablePushButton')), findsNothing);
    });
  });
}
