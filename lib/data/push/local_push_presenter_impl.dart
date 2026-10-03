import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/push/push_payload.dart';
import '../../domain/push/push_models.dart';
import '../../domain/push/push_ports.dart';

/// Android channel for pushes. Must match `ANDROID_CHANNEL_ID` in the
/// Worker (`src/push/fcm.ts`) and the `default_notification_channel_id`
/// manifest meta-data added by `scripts/patch_android_manifest.sh`.
const pushChannelId = 'hwc_push';

/// `flutter_local_notifications` exposes ONE tap callback per app (the last
/// `initialize()` wins), and two things in HWC initialize it: this push
/// presenter and the water-reminder `NotificationService`. Both pass
/// [handle] so neither silently replaces the other's callback; reminder taps
/// carry no payload and are ignored here.
class LocalNotificationTapBridge {
  const LocalNotificationTapBridge._();

  static final _payloads = StreamController<String>.broadcast();
  static Stream<String> get payloads => _payloads.stream;

  static void handle(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) _payloads.add(payload);
  }
}

/// Shows a push that arrived while the app is in the foreground. (The OS
/// displays background/terminated pushes itself, so those never reach here.)
class LocalPushPresenterImpl implements LocalPushPresenter {
  LocalPushPresenterImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Stream<PushPayload> get taps => LocalNotificationTapBridge.payloads
      .map(_decode)
      .where((p) => p != null)
      .cast<PushPayload>();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: LocalNotificationTapBridge.handle,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          pushChannelId,
          'HWC notifications',
          description: 'Messages and updates from HWC',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  @override
  Future<void> show(PushMessage message, PushPayload? payload) async {
    final title = message.title;
    final body = message.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
    await initialize();
    final idSource = message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}';
    await _plugin.show(
      id: idSource.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          'HWC notifications',
          channelDescription: 'Messages and updates from HWC',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload == null
          ? null
          : jsonEncode({'route': payload.route.wireName, 'notification_id': payload.notificationId}),
    );
  }

  static PushPayload? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return PushPayload.tryParse({
        'type': PushPayload.notificationType,
        'route': json['route'],
        'notification_id': json['notification_id'],
      });
    } catch (e) {
      debugPrint('LocalPushPresenter: ignoring malformed tap payload');
      return null;
    }
  }
}
