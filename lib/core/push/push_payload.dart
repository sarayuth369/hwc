/// In-app destinations a push can open. Mirrors `PUSH_ROUTES` in the Worker
/// (`src/push/pushDispatcher.ts`) -- the contract is a closed set of app
/// screens, never a URL, so a push can never navigate anywhere unexpected.
enum PushRoute {
  home('home', 0),
  health('health', 1),
  aiTalk('ai_talk', 2),
  notifications('notifications', 3),
  profile('profile', 4);

  const PushRoute(this.wireName, this.tabIndex);

  /// The exact string carried in the push `route` field.
  final String wireName;

  /// Index of the matching tab in `HomeShell`.
  final int tabIndex;

  static PushRoute? fromWireName(Object? value) {
    if (value is! String) return null;
    for (final route in PushRoute.values) {
      if (route.wireName == value) return route;
    }
    return null;
  }
}

/// The validated push `data` payload.
///
/// Contract (also enforced server-side): `type == "notification"`, a
/// `notification_id`, and a `route` from [PushRoute]. Nothing else is read
/// -- no health values, chat text or free-form parameters travel in a push.
class PushPayload {
  const PushPayload({required this.route, this.notificationId});

  final PushRoute route;
  final String? notificationId;

  static const String notificationType = 'notification';

  /// Returns null for anything malformed or unknown (wrong type, missing or
  /// unrecognised route, non-string values). Never throws.
  static PushPayload? tryParse(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      if (data['type'] != notificationType) return null;
      final route = PushRoute.fromWireName(data['route']);
      if (route == null) return null;
      final id = data['notification_id'];
      final notificationId = id is String && id.isNotEmpty && id.length <= 64 ? id : null;
      return PushPayload(route: route, notificationId: notificationId);
    } catch (_) {
      return null;
    }
  }
}

/// Short form of a device token for logs ("abc...wxyz") -- a full FCM token
/// is a bearer credential for pushing to a device and must never be logged.
String maskPushToken(String token) =>
    token.length <= 8 ? '***' : '${token.substring(0, 3)}...${token.substring(token.length - 4)}';
