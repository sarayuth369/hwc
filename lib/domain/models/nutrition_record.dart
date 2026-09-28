enum MealType { breakfast, lunch, dinner, snack }

class NutritionRecord {
  const NutritionRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    this.mealType,
    this.description,
    this.calories,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final MealType? mealType;
  final String? description;
  final int? calories;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'logged_at': loggedAt.toIso8601String(),
        if (mealType != null) 'meal_type': mealType!.name,
        if (description != null) 'description': description,
        if (calories != null) 'calories': calories,
      };

  factory NutritionRecord.fromJson(Map<String, dynamic> json) =>
      NutritionRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        mealType: json['meal_type'] == null
            ? null
            : MealType.values.byName(json['meal_type'] as String),
        description: json['description'] as String?,
        calories: json['calories'] as int?,
      );
}
