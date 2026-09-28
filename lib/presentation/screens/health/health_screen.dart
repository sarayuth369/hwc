import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/activity_record.dart';
import '../../../domain/models/nutrition_record.dart';
import '../../../domain/models/sleep_record.dart';
import '../../../domain/models/water_record.dart';
import '../../../domain/models/weight_record.dart';
import '../../../domain/repositories/metric_repositories.dart';

/// Metric logging/history across sleep, activity, water, weight, nutrition.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HistorySection<SleepRecord>(
            title: 'Sleep',
            load: () => context.read<SleepRepository>().recent(),
            label: (r) => '${r.hoursSlept}h',
          ),
          _HistorySection<ActivityRecord>(
            title: 'Activity',
            load: () => context.read<ActivityRepository>().recent(),
            label: (r) =>
                '${r.activityType ?? 'Activity'} · ${r.activeMinutes ?? 0} min',
          ),
          _HistorySection<WaterRecord>(
            title: 'Water',
            load: () => context.read<WaterRepository>().recent(),
            label: (r) => '${r.amountMl} ml',
          ),
          _HistorySection<WeightRecord>(
            title: 'Weight',
            load: () => context.read<WeightRepository>().recent(),
            label: (r) => '${r.weightKg} kg',
          ),
          _HistorySection<NutritionRecord>(
            title: 'Nutrition',
            load: () => context.read<NutritionRepository>().recent(),
            label: (r) => r.mealType?.name ?? r.description ?? 'Meal',
          ),
        ],
      ),
    );
  }
}

class _HistorySection<T> extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.load,
    required this.label,
  });

  final String title;
  final Future<List<T>> Function() load;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: load(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return ExpansionTile(
          title: Text(title),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No entries yet.'),
              )
            else
              for (final item in items) ListTile(title: Text(label(item))),
          ],
        );
      },
    );
  }
}
