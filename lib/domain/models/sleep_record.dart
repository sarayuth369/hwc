enum SleepQuality { poor, fair, good, excellent }

class SleepRecord {
  const SleepRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    required this.hoursSlept,
    this.quality,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final double hoursSlept;
  final SleepQuality? quality;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        // .toUtc() required -- see WaterRecord.toJson()'s comment for why a
        // local DateTime's ISO string silently gets misread as UTC.
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'hours_slept': hoursSlept,
        if (quality != null) 'quality': quality!.name,
      };

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        hoursSlept: (json['hours_slept'] as num).toDouble(),
        quality: json['quality'] == null
            ? null
            : SleepQuality.values.byName(json['quality'] as String),
      );
}
