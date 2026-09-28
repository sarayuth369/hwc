import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/activity_record.dart';
import '../../../domain/models/nutrition_record.dart';
import '../../../domain/models/sleep_record.dart';
import '../../../domain/models/water_record.dart';
import '../../../domain/models/weight_record.dart';
import '../../../domain/repositories/metric_repositories.dart';

/// Metric logging/history across sleep, activity, water, weight, nutrition.
/// When [embedded] is true (hosted as a `HomeShell` tab), it renders just
/// the list — the shell already provides the `Scaffold`/`AppBar`.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HistorySection<SleepRecord>(
          title: 'Sleep',
          icon: Icons.bedtime_outlined,
          load: () => context.read<SleepRepository>().recent(),
          label: (r) => '${r.hoursSlept}h',
        ),
        _HistorySection<ActivityRecord>(
          title: 'Activity',
          icon: Icons.directions_walk,
          load: () => context.read<ActivityRepository>().recent(),
          label: (r) =>
              '${r.activityType ?? 'Activity'} · ${r.activeMinutes ?? 0} min',
        ),
        _HistorySection<WaterRecord>(
          title: 'Water',
          icon: Icons.water_drop_outlined,
          load: () => context.read<WaterRepository>().recent(),
          label: (r) => '${r.amountMl} ml',
        ),
        _HistorySection<WeightRecord>(
          title: 'Weight',
          icon: Icons.monitor_weight_outlined,
          load: () => context.read<WeightRepository>().recent(),
          label: (r) => '${r.weightKg} kg',
        ),
        _HistorySection<NutritionRecord>(
          title: 'Nutrition',
          icon: Icons.restaurant_outlined,
          load: () => context.read<NutritionRepository>().recent(),
          label: (r) => r.mealType?.name ?? r.description ?? 'Meal',
        ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Health')),
      body: body,
    );
  }
}

class _HistorySection<T> extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.icon,
    required this.load,
    required this.label,
  });

  final String title;
  final IconData icon;
  final Future<List<T>> Function() load;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<T>>(
      future: load(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Card(
          child: ExpansionTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
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
          ),
        );
      },
    );
  }
}
