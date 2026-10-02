import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/domain/models/activity_record.dart';
import 'package:bkknex_health_app/domain/models/nutrition_record.dart';
import 'package:bkknex_health_app/domain/models/sleep_record.dart';
import 'package:bkknex_health_app/domain/models/water_record.dart';
import 'package:bkknex_health_app/domain/models/weight_record.dart';

/// Regression: every metric record's `toJson()` must send `logged_at` as an
/// explicit-UTC ISO string. A *local* `DateTime`'s `toIso8601String()` has
/// no timezone suffix, and Postgres's `timestamptz` columns silently read
/// that as the session's (UTC) timezone -- a record logged at 23:30 in a
/// UTC+7 timezone would be stored as 23:30 UTC, then read back as 06:30
/// *the next day* in local time, landing in the wrong calendar day bucket
/// (`core/metrics/daily_bucket.dart`'s `dayKey()`). This is exactly the
/// class of day-boundary bug this codebase has hit before (see
/// `home_screen_test.dart`'s rolling-24h-window regression test).
void main() {
  // A local time late enough in the day that, for any positive UTC offset,
  // the (buggy) naive-as-UTC interpretation lands on a different calendar
  // day than the true UTC instant -- making the regression impossible to
  // miss regardless of which timezone this test happens to run in.
  final lateLocal = DateTime(2026, 6, 15, 23, 30);

  test('WaterRecord.toJson sends an explicit-UTC logged_at', () {
    final json = WaterRecord(userId: 'u1', loggedAt: lateLocal, amountMl: 250).toJson();
    final encoded = json['logged_at'] as String;
    expect(DateTime.parse(encoded).isUtc, isTrue);
    expect(DateTime.parse(encoded), lateLocal.toUtc());
  });

  test('WeightRecord.toJson sends an explicit-UTC logged_at', () {
    final json = WeightRecord(userId: 'u1', loggedAt: lateLocal, weightKg: 70).toJson();
    expect(DateTime.parse(json['logged_at'] as String).isUtc, isTrue);
  });

  test('SleepRecord.toJson sends an explicit-UTC logged_at', () {
    final json = SleepRecord(userId: 'u1', loggedAt: lateLocal, hoursSlept: 7.5).toJson();
    expect(DateTime.parse(json['logged_at'] as String).isUtc, isTrue);
  });

  test('ActivityRecord.toJson sends an explicit-UTC logged_at', () {
    final json = ActivityRecord(userId: 'u1', loggedAt: lateLocal, activeMinutes: 20).toJson();
    expect(DateTime.parse(json['logged_at'] as String).isUtc, isTrue);
  });

  test('NutritionRecord.toJson sends an explicit-UTC logged_at', () {
    final json = NutritionRecord(userId: 'u1', loggedAt: lateLocal, description: 'Rice').toJson();
    expect(DateTime.parse(json['logged_at'] as String).isUtc, isTrue);
  });

  test(
      'round-trip: a record logged just before local midnight still dayKey-buckets to that local day',
      () {
    // This is the actual user-facing symptom: without .toUtc() on write,
    // this round-trip would land one calendar day later than the user
    // actually logged it (in any positive-UTC-offset timezone).
    final json = WaterRecord(userId: 'u1', loggedAt: lateLocal, amountMl: 250).toJson();
    final roundTripped = WaterRecord.fromJson(json);
    expect(roundTripped.loggedAt.toLocal().day, lateLocal.day);
  });
}
