import '../models/notification_item.dart';

/// Real, Supabase-backed notification inbox (see `supabase/migrations/
/// 0002_notifications.sql`). Delivery today is "open the app, this fetches
/// unread rows" -- genuinely real, not a push simulation. A push provider
/// (FCM) can be layered on later purely as a *delivery* mechanism for these
/// same rows, without any change to this interface -- see
/// `PushService` for that seam.
abstract class NotificationRepository {
  Future<List<NotificationItem>> list({int limit = 50});
  Future<int> unreadCount();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
