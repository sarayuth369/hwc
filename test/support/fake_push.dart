import 'dart:async';

import 'package:bkknex_health_app/core/push/push_payload.dart';
import 'package:bkknex_health_app/domain/push/push_models.dart';
import 'package:bkknex_health_app/domain/push/push_ports.dart';

class FakeFcmGateway implements FcmGateway {
  bool initializeThrows = false;
  PushPermissionStatus permission = PushPermissionStatus.granted;
  PushPermissionStatus permissionAfterRequest = PushPermissionStatus.granted;
  bool requestThrows = false;
  String? token = 'fake-fcm-token-aaaaaaaaaaaaaaaaaaaaaaaa';
  PushMessage? initialMessage;
  bool initialMessageThrows = false;

  int initializeCalls = 0;
  int requestCalls = 0;
  int getTokenCalls = 0;

  final refreshController = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushMessage>.broadcast();
  final openedController = StreamController<PushMessage>.broadcast();

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializeThrows) throw Exception('[core/no-app] Firebase not configured');
  }

  @override
  Future<PushPermissionStatus> permissionStatus() async => permission;

  @override
  Future<PushPermissionStatus> requestPermission() async {
    requestCalls++;
    if (requestThrows) throw Exception('permission channel failed');
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshController.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foregroundController.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => openedController.stream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    if (initialMessageThrows) throw Exception('boom');
    return initialMessage;
  }
}

class RegisteredToken {
  RegisteredToken(this.token, this.platform, this.deviceId, this.appVersion);
  final String token;
  final String platform;
  final String deviceId;
  final String appVersion;
}

class FakePushTokenRepository implements PushTokenRepository {
  final registered = <RegisteredToken>[];
  final deactivated = <String>[];
  bool registerThrows = false;
  bool deactivateThrows = false;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String deviceId,
    required String appVersion,
  }) async {
    if (registerThrows) throw Exception('PGRST202 function register_push_token not found');
    registered.add(RegisteredToken(token, platform, deviceId, appVersion));
  }

  @override
  Future<void> deactivate(String token) async {
    if (deactivateThrows) throw Exception('network down');
    deactivated.add(token);
  }
}

class FakeLocalPushPresenter implements LocalPushPresenter {
  final shown = <(PushMessage, PushPayload?)>[];
  bool initializeThrows = false;
  bool showThrows = false;
  final tapController = StreamController<PushPayload>.broadcast();

  @override
  Future<void> initialize() async {
    if (initializeThrows) throw Exception('plugin unavailable');
  }

  @override
  Future<void> show(PushMessage message, PushPayload? payload) async {
    if (showThrows) throw Exception('cannot show');
    shown.add((message, payload));
  }

  @override
  Stream<PushPayload> get taps => tapController.stream;
}

/// Controllable [PushService] for widget tests (HomeShell routing, Settings,
/// sign-out ordering).
class FakePushService implements PushService {
  FakePushService({this.available = true, List<String>? log}) : events = log ?? <String>[];

  final bool available;
  PushPermissionStatus permission = PushPermissionStatus.denied;
  PushPermissionStatus enableResult = PushPermissionStatus.granted;
  PushRoute? pending;
  final routeController = StreamController<PushRoute>.broadcast();
  final inboxController = StreamController<void>.broadcast();
  final List<String> events;

  @override
  bool get isAvailable => available;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> onSignedIn() async => events.add('signedIn');

  @override
  Future<void> onSigningOut() async => events.add('signingOut');

  @override
  Future<PushPermissionStatus> permissionStatus() async => permission;

  @override
  Future<PushPermissionStatus> enable() async {
    events.add('enable');
    permission = enableResult;
    return enableResult;
  }

  @override
  Stream<PushRoute> get routeRequests => routeController.stream;

  @override
  PushRoute? takePendingRoute() {
    final p = pending;
    pending = null;
    return p;
  }

  @override
  Stream<void> get inboxChanged => inboxController.stream;

  @override
  void dispose() {}
}
