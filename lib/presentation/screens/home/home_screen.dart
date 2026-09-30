import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/wellness_summary.dart';
import '../../../domain/repositories/daily_summary_repository.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/wellness_score_card.dart';
import '../quick_actions/quick_add_sheet.dart';

/// Home tab content — no `Scaffold`/`AppBar` of its own, `HomeShell` hosts
/// those plus the bottom nav bar. Redesigned per the product-vision board:
/// a greeting, the hero Wellness Score card, a metric summary grid, and a
/// prominent "Talk to AI" call to action.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onTalkToAi,
    this.onDataChanged,
    this.now = DateTime.now,
  });

  final VoidCallback? onTalkToAi;

  /// Called after Quick Add closes, so a sibling screen (Health, kept alive
  /// in `HomeShell`'s `IndexedStack`) can refresh too — Quick Add can change
  /// data this screen doesn't itself display.
  final VoidCallback? onDataChanged;

  /// Overridable clock for [_greeting] (real callers never pass this —
  /// it defaults to the real time). Without this seam, the golden
  /// screenshot test for this screen silently broke depending on the real
  /// wall-clock hour at test-run time: "Good Afternoon" (14 chars) wraps
  /// to a second line at this screen's test width where "Good Morning"/
  /// "Good Evening" (12 chars each) don't, so regenerating the golden at
  /// one hour and re-running the suite at a different hour produced a
  /// real, reproducible pixel diff that had nothing to do with any code
  /// change — confirmed by testing in isolation and tracing to
  /// `DateTime.now().hour` before adding this fix.
  final DateTime Function() now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WellnessSummary?> _summaryFuture;
  late Future<String?> _greetingNameFuture;
  late Future<_TodayMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _greetingNameFuture = _loadGreetingName();
    _metricsFuture = _loadMetrics();
  }

  Future<WellnessSummary?> _loadSummary() =>
      context.read<DailySummaryRepository>().summaryFor(DateTime.now());

  Future<String?> _loadGreetingName() async {
    final profile = await context.read<ProfileRepository>().fetchProfile();
    return profile?.displayName;
  }

  Future<_TodayMetrics> _loadMetrics() async {
    final sleepRepository = context.read<SleepRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final waterRepository = context.read<WaterRepository>();
    final nutritionRepository = context.read<NutritionRepository>();
    final sleep = await sleepRepository.recent(days: 1);
    final activity = await activityRepository.recent(days: 1);
    final water = await waterRepository.recent(days: 1);
    final nutrition = await nutritionRepository.recent(days: 1);
    return _TodayMetrics(
      sleepHours: sleep.isEmpty ? null : sleep.last.hoursSlept,
      activeMinutes: activity.fold<int>(0, (sum, a) => sum + (a.activeMinutes ?? 0)),
      waterMl: water.fold<int>(0, (sum, w) => sum + w.amountMl),
      mealsLogged: nutrition.length,
    );
  }

  void _refresh() => setState(() {
        _summaryFuture = _loadSummary();
        _metricsFuture = _loadMetrics();
      });

  String _greeting() {
    final hour = widget.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<String?>(
            future: _greetingNameFuture,
            builder: (context, snapshot) {
              final name = snapshot.data;
              return Text(
                name == null || name.isEmpty
                    ? _greeting()
                    : '${_greeting()}, $name',
                key: const Key('homeGreeting'),
                style: theme.textTheme.headlineMedium,
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<WellnessSummary?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return WellnessScoreCard(summary: snapshot.data);
            },
          ),
          const SizedBox(height: 16),
          const AiInsightCard(),
          const SizedBox(height: 16),
          FutureBuilder<_TodayMetrics>(
            future: _metricsFuture,
            builder: (context, snapshot) {
              final metrics = snapshot.data ?? const _TodayMetrics();
              // A Column of Rows (not GridView.count) so each tile sizes to
              // its own content — a fixed aspect ratio overflowed once
              // Senior Mode's larger type scale was applied.
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.bedtime_outlined,
                          label: 'Sleep',
                          value: metrics.sleepHours == null
                              ? 'No data'
                              : '${metrics.sleepHours!.toStringAsFixed(1)}h',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.directions_walk,
                          label: 'Activity',
                          value: '${metrics.activeMinutes} min',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.water_drop_outlined,
                          label: 'Water',
                          value:
                              '${(metrics.waterMl / 1000).toStringAsFixed(1)} L',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.restaurant_outlined,
                          label: 'Nutrition',
                          value: metrics.mealsLogged == 0
                              ? 'No data'
                              : '${metrics.mealsLogged} logged',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('homeTalkToAiButton'),
            onPressed: widget.onTalkToAi,
            icon: const Icon(Icons.mic),
            label: const Text('Talk to AI'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('homeQuickAddButton'),
            onPressed: () => showQuickAddSheet(
              context,
              onChanged: () {
                _refresh();
                widget.onDataChanged?.call();
              },
            ),
            icon: const Icon(Icons.add),
            label: const Text('Quick Add'),
          ),
        ],
      ),
    );
  }
}

class _TodayMetrics {
  const _TodayMetrics({
    this.sleepHours,
    this.activeMinutes = 0,
    this.waterMl = 0,
    this.mealsLogged = 0,
  });

  final double? sleepHours;
  final int activeMinutes;
  final int waterMl;
  final int mealsLogged;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
