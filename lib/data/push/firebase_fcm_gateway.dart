import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/push/push_models.dart';
import '../../domain/push/push_ports.dart';

/// The only place that touches `firebase_core` / `firebase_messaging`.
///
/// Firebase is configured natively from the local, uncommitted
/// `android/app/google-services.json` (Google Services Gradle plugin), so
/// `Firebase.initializeApp()` takes no options. In a build without that file
/// it throws, which [FcmPushService] treats as "push disabled".
class FirebaseFcmGateway implements FcmGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static PushMessage _toPushMessage(RemoteMessage m) => PushMessage(
        messageId: m.messageId,
        title: m.notification?.title,
        body: m.notification?.body,
        data: Map<String, dynamic>.from(m.data),
      );

  static PushPermissionStatus _toStatus(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional
          ? PushPermissionStatus.granted
          : PushPermissionStatus.denied;

  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  @override
  Future<PushPermissionStatus> permissionStatus() async =>
      _toStatus((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      _toStatus((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(_toPushMessage);

  @override
  Stream<PushMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp.map(_toPushMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }
}
