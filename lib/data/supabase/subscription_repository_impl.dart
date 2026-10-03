import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/subscription_repository.dart';

/// Reads the signed-in user's entitlement from the server-written
/// `subscriptions` row. RLS lets a user read ONLY their own row and never
/// write it: the only writer is the Worker (service-role) after it verified a
/// Google Play purchase with Google. The client cannot grant itself Premium.
///
/// When the row can't be read (offline), the last server-confirmed answer is
/// used until the paid period it was confirmed for ends -- so a paying user
/// isn't downgraded by a flaky connection, and a lapsed one is never kept
/// beyond their period end. (The cache only drives client-side UI such as ad
/// suppression; nothing server-side trusts it.)
class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(
    this._client,
    this._prefs, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static const _cacheKey = 'entitlement_cache_v1';

  @override
  Future<SubscriptionTier> currentTier() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return SubscriptionTier.free;

    try {
      final row = await _client
          .from('subscriptions')
          .select('tier, status, current_period_end')
          .eq('user_id', userId)
          .maybeSingle();
      final until = premiumUntil(row, _now());
      await _writeCache(userId, until);
      return until == null ? SubscriptionTier.free : SubscriptionTier.premium;
    } catch (_) {
      final until = _readCache(userId);
      return until != null && until.isAfter(_now())
          ? SubscriptionTier.premium
          : SubscriptionTier.free;
    }
  }

  /// The moment Premium access ends for [row], or null when the row does not
  /// currently grant Premium. Premium requires a premium tier, an
  /// active/cancelled (paid-through) status, AND a period end still in the
  /// future -- a stale `premium` row never grants access past its period.
  static DateTime? premiumUntil(Map<String, dynamic>? row, DateTime now) {
    if (row == null) return null;
    if (row['tier'] != 'premium') return null;
    final status = row['status'];
    if (status != 'active' && status != 'cancelled') return null;
    final raw = row['current_period_end'];
    if (raw is! String) return null;
    final end = DateTime.tryParse(raw);
    if (end == null || !end.isAfter(now)) return null;
    return end;
  }

  Future<void> _writeCache(String userId, DateTime? until) async {
    try {
      if (until == null) {
        await _prefs.remove(_cacheKey);
      } else {
        await _prefs.setString(
          _cacheKey,
          jsonEncode({'uid': userId, 'until': until.toUtc().toIso8601String()}),
        );
      }
    } catch (_) {}
  }

  DateTime? _readCache(String userId) {
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['uid'] != userId) return null;
      return DateTime.tryParse(json['until'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }
}
