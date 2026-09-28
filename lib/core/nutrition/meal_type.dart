import '../../domain/models/nutrition_record.dart';

/// Shared by Quick Add and the Food Scanner so both infer the same meal
/// type from the time of day, rather than duplicating the thresholds.
MealType inferMealTypeFromTime([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 11) return MealType.breakfast;
  if (hour < 16) return MealType.lunch;
  if (hour < 21) return MealType.dinner;
  return MealType.snack;
}
