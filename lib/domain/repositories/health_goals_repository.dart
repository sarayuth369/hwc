import '../models/health_goal.dart';

abstract class HealthGoalsRepository {
  Future<List<HealthGoalRecord>> fetchGoals();
  Future<void> setGoal(HealthGoalRecord goal);
}
