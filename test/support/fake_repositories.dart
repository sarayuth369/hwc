import 'package:bkknex_health_app/domain/models/activity_record.dart';
import 'package:bkknex_health_app/domain/models/nutrition_record.dart';
import 'package:bkknex_health_app/domain/models/sleep_record.dart';
import 'package:bkknex_health_app/domain/models/user_preferences.dart';
import 'package:bkknex_health_app/domain/models/user_profile.dart';
import 'package:bkknex_health_app/domain/models/water_record.dart';
import 'package:bkknex_health_app/domain/models/weight_record.dart';
import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/daily_summary_repository.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';

class FakeCurrentUserService implements CurrentUserService {
  @override
  String? currentUserId = 'test-user';
}

class FakeProfileRepository implements ProfileRepository {
  String? displayName;
  UserPreferences? preferences;

  @override
  Future<UserProfile?> fetchProfile() async =>
      const UserProfile(userId: 'test-user', displayName: null);

  @override
  Future<UserPreferences?> fetchPreferences() async => preferences;

  @override
  Future<void> updateDisplayName(String name) async {
    displayName = name;
  }

  @override
  Future<void> updatePreferences(UserPreferences prefs) async {
    preferences = prefs;
  }
}

class FakeDailySummaryRepository implements DailySummaryRepository {
  WellnessSummary? summary;

  @override
  Future<WellnessSummary?> summaryFor(DateTime date) async => summary;
}

class FakeSleepRepository implements SleepRepository {
  final List<SleepRecord> logged = [];

  @override
  Future<void> logSleep(SleepRecord record) async => logged.add(record);

  @override
  Future<List<SleepRecord>> recent({int days = 7}) async => logged;
}

class FakeActivityRepository implements ActivityRepository {
  final List<ActivityRecord> logged = [];

  @override
  Future<void> logActivity(ActivityRecord record) async => logged.add(record);

  @override
  Future<List<ActivityRecord>> recent({int days = 7}) async => logged;
}

class FakeWaterRepository implements WaterRepository {
  final List<WaterRecord> logged = [];

  @override
  Future<void> logWater(WaterRecord record) async => logged.add(record);

  @override
  Future<List<WaterRecord>> recent({int days = 7}) async => logged;
}

class FakeWeightRepository implements WeightRepository {
  final List<WeightRecord> logged = [];

  @override
  Future<void> logWeight(WeightRecord record) async => logged.add(record);

  @override
  Future<List<WeightRecord>> recent({int days = 7}) async => logged;
}

class FakeNutritionRepository implements NutritionRepository {
  final List<NutritionRecord> logged = [];

  @override
  Future<void> logNutrition(NutritionRecord record) async =>
      logged.add(record);

  @override
  Future<List<NutritionRecord>> recent({int days = 7}) async => logged;
}
