class WeightRecord {
  const WeightRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    required this.weightKg,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final double weightKg;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        // .toUtc() required -- see WaterRecord.toJson()'s comment for why a
        // local DateTime's ISO string silently gets misread as UTC.
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'weight_kg': weightKg,
      };

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        weightKg: (json['weight_kg'] as num).toDouble(),
      );
}
