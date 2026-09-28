import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/sleep_record.dart';
import '../../domain/models/activity_record.dart';
import '../../domain/models/water_record.dart';
import '../../domain/models/weight_record.dart';
import '../../domain/models/nutrition_record.dart';
import '../../domain/repositories/metric_repositories.dart';
import '../local/metric_write_queue.dart';
import 'offline_first_metric_repository.dart';

class SleepRepositoryImpl implements SleepRepository {
  SleepRepositoryImpl(SupabaseClient client, MetricWriteQueue queue)
      : _engine = OfflineFirstMetricRepository<SleepRecord>(
          client: client,
          queue: queue,
          table: 'sleep_records',
          toJson: (r) => r.toJson(),
          fromJson: SleepRecord.fromJson,
        );

  final OfflineFirstMetricRepository<SleepRecord> _engine;

  @override
  Future<void> logSleep(SleepRecord record) => _engine.log(record);

  @override
  Future<List<SleepRecord>> recent({int days = 7}) =>
      _engine.recent(days: days);
}

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(SupabaseClient client, MetricWriteQueue queue)
      : _engine = OfflineFirstMetricRepository<ActivityRecord>(
          client: client,
          queue: queue,
          table: 'activity_records',
          toJson: (r) => r.toJson(),
          fromJson: ActivityRecord.fromJson,
        );

  final OfflineFirstMetricRepository<ActivityRecord> _engine;

  @override
  Future<void> logActivity(ActivityRecord record) => _engine.log(record);

  @override
  Future<List<ActivityRecord>> recent({int days = 7}) =>
      _engine.recent(days: days);
}

class WaterRepositoryImpl implements WaterRepository {
  WaterRepositoryImpl(SupabaseClient client, MetricWriteQueue queue)
      : _engine = OfflineFirstMetricRepository<WaterRecord>(
          client: client,
          queue: queue,
          table: 'water_records',
          toJson: (r) => r.toJson(),
          fromJson: WaterRecord.fromJson,
        );

  final OfflineFirstMetricRepository<WaterRecord> _engine;

  @override
  Future<void> logWater(WaterRecord record) => _engine.log(record);

  @override
  Future<List<WaterRecord>> recent({int days = 7}) =>
      _engine.recent(days: days);
}

class WeightRepositoryImpl implements WeightRepository {
  WeightRepositoryImpl(SupabaseClient client, MetricWriteQueue queue)
      : _engine = OfflineFirstMetricRepository<WeightRecord>(
          client: client,
          queue: queue,
          table: 'weight_records',
          toJson: (r) => r.toJson(),
          fromJson: WeightRecord.fromJson,
        );

  final OfflineFirstMetricRepository<WeightRecord> _engine;

  @override
  Future<void> logWeight(WeightRecord record) => _engine.log(record);

  @override
  Future<List<WeightRecord>> recent({int days = 7}) =>
      _engine.recent(days: days);
}

class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(SupabaseClient client, MetricWriteQueue queue)
      : _engine = OfflineFirstMetricRepository<NutritionRecord>(
          client: client,
          queue: queue,
          table: 'nutrition_records',
          toJson: (r) => r.toJson(),
          fromJson: NutritionRecord.fromJson,
        );

  final OfflineFirstMetricRepository<NutritionRecord> _engine;

  @override
  Future<void> logNutrition(NutritionRecord record) => _engine.log(record);

  @override
  Future<List<NutritionRecord>> recent({int days = 7}) =>
      _engine.recent(days: days);
}
