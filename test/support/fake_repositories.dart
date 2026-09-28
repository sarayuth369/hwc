import 'dart:async';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:bkknex_health_app/domain/models/activity_record.dart';
import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/models/nutrition_record.dart';
import 'package:bkknex_health_app/domain/models/sleep_record.dart';
import 'package:bkknex_health_app/domain/models/user_preferences.dart';
import 'package:bkknex_health_app/domain/models/user_profile.dart';
import 'package:bkknex_health_app/domain/models/water_record.dart';
import 'package:bkknex_health_app/domain/models/weight_record.dart';
import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/auth_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/daily_summary_repository.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<bool>.broadcast();
  bool _signedIn = true;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  void setSignedIn(bool signedIn) {
    _signedIn = signedIn;
    _controller.add(signedIn);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    setSignedIn(true);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    setSignedIn(true);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    setSignedIn(false);
  }
}

class FakeCurrentUserService implements CurrentUserService {
  @override
  String? currentUserId = 'test-user';

  @override
  String? accessToken = 'test-access-token';
}

class FakeAiRepository implements AiRepository {
  Map<String, dynamic>? lastChatRequest;
  Map<String, dynamic> chatResponse = {
    'reply': 'This is a test reply.',
    'conversationId': 'test-conversation',
  };
  AiChatFailure? failure;

  /// Optional artificial delay so widget tests can observe the loading
  /// state between a `pump()` and `pumpAndSettle()`.
  Duration delay = Duration.zero;

  @override
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody) async {
    lastChatRequest = requestBody;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return chatResponse;
  }

  @override
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody) =>
      chat(requestBody);
}

class FakeProfileRepository implements ProfileRepository {
  String? displayName;
  UserPreferences? preferences;

  @override
  Future<UserProfile?> fetchProfile() async =>
      UserProfile(userId: 'test-user', displayName: displayName);

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

/// Every provider `HomeShell`/`AuthGate` need, wired to fresh fakes. Widget
/// tests that pump the real navigation shell (whose `IndexedStack` builds
/// all four tabs immediately) need this full set, not just the providers
/// for the tab under test.
List<SingleChildWidget> fullProviderSet({
  FakeCurrentUserService? currentUserService,
  FakeAuthRepository? authRepository,
  FakeProfileRepository? profileRepository,
  FakeAiRepository? aiRepository,
  FakeDailySummaryRepository? dailySummaryRepository,
  FakeSleepRepository? sleepRepository,
  FakeActivityRepository? activityRepository,
  FakeWaterRepository? waterRepository,
  FakeWeightRepository? weightRepository,
  FakeNutritionRepository? nutritionRepository,
}) {
  return [
    Provider<CurrentUserService>.value(
      value: currentUserService ?? FakeCurrentUserService(),
    ),
    Provider<AuthRepository>.value(
      value: authRepository ?? FakeAuthRepository(),
    ),
    Provider<ProfileRepository>.value(
      value: profileRepository ?? FakeProfileRepository(),
    ),
    Provider<AiRepository>.value(
      value: aiRepository ?? FakeAiRepository(),
    ),
    Provider<DailySummaryRepository>.value(
      value: dailySummaryRepository ?? FakeDailySummaryRepository(),
    ),
    Provider<SleepRepository>.value(
      value: sleepRepository ?? FakeSleepRepository(),
    ),
    Provider<ActivityRepository>.value(
      value: activityRepository ?? FakeActivityRepository(),
    ),
    Provider<WaterRepository>.value(
      value: waterRepository ?? FakeWaterRepository(),
    ),
    Provider<WeightRepository>.value(
      value: weightRepository ?? FakeWeightRepository(),
    ),
    Provider<NutritionRepository>.value(
      value: nutritionRepository ?? FakeNutritionRepository(),
    ),
  ];
}
