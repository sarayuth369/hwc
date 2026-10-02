class ActivityRecord {
  const ActivityRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    this.steps,
    this.activeMinutes,
    this.activityType,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final int? steps;
  final int? activeMinutes;
  final String? activityType;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        // .toUtc() required -- see WaterRecord.toJson()'s comment for why a
        // local DateTime's ISO string silently gets misread as UTC.
        'logged_at': loggedAt.toUtc().toIso8601String(),
        if (steps != null) 'steps': steps,
        if (activeMinutes != null) 'active_minutes': activeMinutes,
        if (activityType != null) 'activity_type': activityType,
      };

  factory ActivityRecord.fromJson(Map<String, dynamic> json) =>
      ActivityRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        steps: json['steps'] as int?,
        activeMinutes: json['active_minutes'] as int?,
        activityType: json['activity_type'] as String?,
      );
}
