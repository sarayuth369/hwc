import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/notification_item.dart';
import '../../../domain/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<NotificationRepository>().list();
  }

  void _reload() {
    setState(() {
      _future = context.read<NotificationRepository>().list();
    });
  }

  Future<void> _markAllRead() async {
    await context.read<NotificationRepository>().markAllAsRead();
    _reload();
  }

  Future<void> _markRead(NotificationItem item) async {
    if (!item.isUnread) return;
    await context.read<NotificationRepository>().markAsRead(item.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            key: const Key('markAllReadButton'),
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<NotificationItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      "You're all caught up.",
                      key: Key('notificationsEmptyState'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  key: Key('notificationItem_${item.id}'),
                  onTap: () => _markRead(item),
                  leading: Icon(
                    _iconFor(item.category),
                    color: item.isUnread
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight:
                          item.isUnread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(item.body),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat.MMMd().add_jm().format(item.createdAt.toLocal()),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.reminder:
        return Icons.alarm;
      case NotificationCategory.insight:
        return Icons.insights;
      case NotificationCategory.admin:
        return Icons.campaign_outlined;
      case NotificationCategory.system:
        return Icons.info_outline;
      case NotificationCategory.general:
        return Icons.notifications_outlined;
    }
  }
}
