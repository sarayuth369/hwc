import '../models/wellness_summary.dart';

abstract class DailySummaryRepository {
  /// Fetches (recomputing via the `compute_wellness_score_v1` Postgres
  /// function if needed) the Wellness Score summary for [date]. Score math
  /// lives ONLY in Postgres — this layer renders whatever the function
  /// returns and must never compute or adjust the score client-side.
  Future<WellnessSummary?> summaryFor(DateTime date);

  /// The last [days] days' summaries (oldest first), skipping any day with
  /// no data. Calls the same `compute_wellness_score_v1` RPC once per day —
  /// no new backend endpoint, just repeated use of the existing one.
  Future<List<WellnessSummary>> recentSummaries({int days = 7});
}
