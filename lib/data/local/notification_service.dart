import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Real local wellness reminders (device-scheduled, no server involved) —
/// not a "coming soon" placeholder. Server-driven/personalized push
/// notifications (e.g. an AI-timed nudge) would need Firebase Cloud
/// Messaging or APNs plus a backend trigger, neither of which exists yet;
/// that's a genuine, separate gap, documented rather than faked.
class NotificationService {
  NotificationService(this._prefs);

  static const _enabledKey = 'water_reminder_enabled_v1';
  static const _hourKey = 'water_reminder_hour_v1';
  static const _minuteKey = 'water_reminder_minute_v1';
  static const _notificationId = 1001;
  static const _channelId = 'wellness_reminders';

  final SharedPreferences _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;

  TimeOfDay get reminderTime => TimeOfDay(
        hour: _prefs.getInt(_hourKey) ?? 10,
        minute: _prefs.getInt(_minuteKey) ?? 0,
      );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  /// Returns whether permission was granted (Android 13+ requires a
  /// runtime request; earlier versions grant implicitly).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> setEnabled(bool enabled, {TimeOfDay? time}) async {
    await _prefs.setBool(_enabledKey, enabled);
    if (time != null) {
      await _prefs.setInt(_hourKey, time.hour);
      await _prefs.setInt(_minuteKey, time.minute);
    }
    if (!enabled) {
      await _ensureInitialized();
      await _plugin.cancel(id: _notificationId);
      return;
    }
    final granted = await requestPermission();
    if (!granted) {
      await _prefs.setBool(_enabledKey, false);
      return;
    }
    await _scheduleDaily();
  }

  Future<void> _scheduleDaily() async {
    await _ensureInitialized();
    final time = reminderTime;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Stay hydrated',
      body: 'Time to drink some water.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Wellness Reminders',
          channelDescription: 'Daily wellness reminders like drinking water',
          importance: Importance.defaultImportance,
        ),
      ),
      // Inexact scheduling: appropriate for a "sometime around this time"
      // wellness nudge, and avoids needing Android 12+'s sensitive
      // SCHEDULE_EXACT_ALARM permission for a precise alarm this isn't.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
