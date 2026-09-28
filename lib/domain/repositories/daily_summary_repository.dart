import '../models/wellness_summary.dart';

abstract class DailySummaryRepository {
  /// Fetches (recomputing via the `compute_wellness_score_v1` Postgres
  /// function if needed) the Wellness Score summary for [date]. Score math
  /// lives ONLY in Postgres — this layer renders whatever the function
  /// returns and must never compute or adjust the score client-side.
  Future<WellnessSummary?> summaryFor(DateTime date);
}
