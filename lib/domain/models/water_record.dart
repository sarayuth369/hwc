class WaterRecord {
  const WaterRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    required this.amountMl,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final int amountMl;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        // .toUtc() is required, not cosmetic: a local DateTime's
        // toIso8601String() has no timezone suffix, so Postgres's
        // `timestamptz` column silently interprets it as the session's
        // (UTC) timezone -- e.g. a true 23:30 Bangkok (UTC+7) log would be
        // stored as 23:30 UTC, re-read as 06:30 the next day local time,
        // and misattributed to the wrong calendar day in dayKey() bucketing.
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'amount_ml': amountMl,
      };

  factory WaterRecord.fromJson(Map<String, dynamic> json) => WaterRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}
