enum NotificationCategory { general, reminder, insight, admin, system }

NotificationCategory _categoryFromString(String value) =>
    NotificationCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => NotificationCategory.general,
    );

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.deepLink,
    this.readAt,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? deepLink;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        category: _categoryFromString(json['category'] as String? ?? 'general'),
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        deepLink: json['deep_link'] as String?,
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
      );
}
