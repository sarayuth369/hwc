import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/health_goal.dart';
import '../../domain/repositories/health_goals_repository.dart';

class HealthGoalsRepositoryImpl implements HealthGoalsRepository {
  HealthGoalsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<HealthGoalRecord>> fetchGoals() async {
    final rows = await _client.from('health_goals').select();
    return (rows as List<dynamic>)
        .map((r) => HealthGoalRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> setGoal(HealthGoalRecord goal) async {
    await _client.from('health_goals').upsert(goal.toJson());
  }
}
