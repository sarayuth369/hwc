/// Shared "which calendar day does this record belong to" logic, so Home's
/// "today" summary and Health's 7/30-day charts can never disagree about
/// where a record falls — both read from the same local-calendar-day
/// boundary rather than each rolling their own rolling-window math.
library;

/// Local midnight for [dt] — the key used to group records by calendar day.
DateTime dayKey(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  return DateTime(local.year, local.month, local.day);
}

/// Groups [records] by local calendar day using [dateOf] to extract each
/// record's timestamp. A record outside `[since, now]` is still included if
/// present -- callers are expected to have already queried a wide-enough
/// window; this only buckets, it doesn't filter.
Map<DateTime, List<T>> bucketByDay<T>(
  List<T> records,
  DateTime Function(T) dateOf,
) {
  final buckets = <DateTime, List<T>>{};
  for (final record in records) {
    final key = dayKey(dateOf(record));
    (buckets[key] ??= []).add(record);
  }
  return buckets;
}

/// The last [days] calendar-day keys, oldest first, ending today -- the
/// fixed X-axis a chart/summary iterates over regardless of which days
/// actually have data (so a day with nothing logged still gets its own
/// slot, rather than the chart silently compressing around gaps).
List<DateTime> recentDayKeys(DateTime now, int days) {
  final today = dayKey(now);
  return List.generate(
    days,
    (i) => today.subtract(Duration(days: days - 1 - i)),
  );
}
