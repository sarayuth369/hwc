enum HealthGoalType { sleep, activity, hydration, weight, nutrition }

class HealthGoalRecord {
  const HealthGoalRecord({
    this.id,
    required this.userId,
    required this.goalType,
    this.targetValue,
    this.isActive = true,
  });

  final String? id;
  final String userId;
  final HealthGoalType goalType;
  final double? targetValue;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'goal_type': goalType.name,
        if (targetValue != null) 'target_value': targetValue,
        'is_active': isActive,
      };

  factory HealthGoalRecord.fromJson(Map<String, dynamic> json) =>
      HealthGoalRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        goalType: HealthGoalType.values.byName(json['goal_type'] as String),
        targetValue: (json['target_value'] as num?)?.toDouble(),
        isActive: json['is_active'] as bool? ?? true,
      );
}
