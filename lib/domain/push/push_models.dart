/// Platform-neutral view of an incoming push (a trimmed-down
/// `firebase_messaging` `RemoteMessage`), so nothing outside
/// `lib/data/push/` depends on the Firebase types.
class PushMessage {
  const PushMessage({this.messageId, this.title, this.body, this.data = const {}});

  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

enum PushPermissionStatus { granted, denied }
