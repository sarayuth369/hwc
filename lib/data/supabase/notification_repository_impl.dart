import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<NotificationItem>> list({int limit = 50}) async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => NotificationItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> unreadCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
    return (rows as List).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
  }
}
