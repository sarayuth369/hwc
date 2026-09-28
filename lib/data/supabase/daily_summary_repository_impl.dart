import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/wellness_summary.dart';
import '../../domain/repositories/daily_summary_repository.dart';

class DailySummaryRepositoryImpl implements DailySummaryRepository {
  DailySummaryRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<WellnessSummary?> summaryFor(DateTime date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final dateOnly = date.toIso8601String().split('T').first;

    // Score math lives entirely in this Postgres function (contract 2) —
    // the client only ever renders the fields it returns.
    await _client.rpc('compute_wellness_score_v1', params: {
      'p_user_id': userId,
      'p_summary_date': dateOnly,
    });

    final row = await _client
        .from('daily_health_summary')
        .select()
        .eq('user_id', userId)
        .eq('summary_date', dateOnly)
        .maybeSingle();
    if (row == null) return null;
    return WellnessSummary.fromJson(row);
  }

  @override
  Future<List<WellnessSummary>> recentSummaries({int days = 7}) async {
    final today = DateTime.now();
    final results = <WellnessSummary>[];
    for (var i = days - 1; i >= 0; i--) {
      final summary = await summaryFor(today.subtract(Duration(days: i)));
      if (summary != null) results.add(summary);
    }
    return results;
  }
}
