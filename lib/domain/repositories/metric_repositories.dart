import '../models/sleep_record.dart';
import '../models/activity_record.dart';
import '../models/water_record.dart';
import '../models/weight_record.dart';
import '../models/nutrition_record.dart';

abstract class SleepRepository {
  Future<void> logSleep(SleepRecord record);
  Future<List<SleepRecord>> recent({int days = 7});
}

abstract class ActivityRepository {
  Future<void> logActivity(ActivityRecord record);
  Future<List<ActivityRecord>> recent({int days = 7});
}

abstract class WaterRepository {
  Future<void> logWater(WaterRecord record);
  Future<List<WaterRecord>> recent({int days = 7});
}

abstract class WeightRepository {
  Future<void> logWeight(WeightRecord record);
  Future<List<WeightRecord>> recent({int days = 7});
}

abstract class NutritionRepository {
  Future<void> logNutrition(NutritionRecord record);
  Future<List<NutritionRecord>> recent({int days = 7});
}
