import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/metrics/daily_bucket.dart';
import '../../domain/repositories/metric_repositories.dart';

enum _ChartMetric { sleep, activity, water, nutrition, weight }

enum _ChartRange { sevenDay, thirtyDay }

class _DayValue {
  const _DayValue(this.day, this.value);
  final DateTime day;
  final double? value;
}

/// A real 7-day/30-day health chart reading straight from the same metric
/// repositories Home's "today" summary reads (via the same `dayKey`
/// bucketing in `daily_bucket.dart`), so the two screens can't disagree on
/// what a given day's numbers are. No synthetic data is ever generated to
/// fill a sparse chart — a day with nothing logged is a genuine gap, shown
/// as an empty slot, never a invented zero.
class HealthChartSection extends StatefulWidget {
  const HealthChartSection({super.key});

  @override
  State<HealthChartSection> createState() => _HealthChartSectionState();
}

class _HealthChartSectionState extends State<HealthChartSection> {
  _ChartMetric _metric = _ChartMetric.sleep;
  _ChartRange _range = _ChartRange.sevenDay;

  // Fetched once for the widest range (30 days) and reused for both views
  // -- avoids two round trips when the user just toggles 7/30-day.
  Future<Map<_ChartMetric, List<_DayValue>>>? _dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= _loadAll();
  }

  Future<List<_DayValue>> _seriesFor<T>(
    List<T> records,
    DateTime Function(T) dateOf,
    double Function(List<T>) aggregate,
  ) async {
    final buckets = bucketByDay(records, dateOf);
    final days = recentDayKeys(DateTime.now(), 30);
    return [
      for (final day in days)
        _DayValue(day, buckets[day] == null ? null : aggregate(buckets[day]!)),
    ];
  }

  Future<Map<_ChartMetric, List<_DayValue>>> _loadAll() async {
    // Read every repository before the first await -- context.read()
    // itself doesn't need a mounted check, but the analyzer can't tell
    // that apart from a real "BuildContext across an async gap" risk.
    final sleepRepository = context.read<SleepRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final waterRepository = context.read<WaterRepository>();
    final nutritionRepository = context.read<NutritionRepository>();
    final weightRepository = context.read<WeightRepository>();

    final sleep = await sleepRepository.recent(days: 30);
    final activity = await activityRepository.recent(days: 30);
    final water = await waterRepository.recent(days: 30);
    final nutrition = await nutritionRepository.recent(days: 30);
    final weight = await weightRepository.recent(days: 30);

    return {
      _ChartMetric.sleep: await _seriesFor(
        sleep,
        (r) => r.loggedAt,
        (day) => day.fold<double>(0, (sum, r) => sum + r.hoursSlept),
      ),
      _ChartMetric.activity: await _seriesFor(
        activity,
        (r) => r.loggedAt,
        (day) => day.fold<double>(0, (sum, r) => sum + (r.activeMinutes ?? 0)),
      ),
      _ChartMetric.water: await _seriesFor(
        water,
        (r) => r.loggedAt,
        (day) => day.fold<double>(0, (sum, r) => sum + r.amountMl) / 1000,
      ),
      _ChartMetric.nutrition: await _seriesFor(
        nutrition,
        (r) => r.loggedAt,
        (day) => day.length.toDouble(),
      ),
      _ChartMetric.weight: await _seriesFor(
        weight,
        (r) => r.loggedAt,
        // Weight isn't additive -- the last entry logged that day, not a sum.
        (day) => day.last.weightKg,
      ),
    };
  }

  static const _labels = {
    _ChartMetric.sleep: ('Sleep', 'h', Icons.bedtime_outlined),
    _ChartMetric.activity: ('Activity', 'min', Icons.directions_walk),
    _ChartMetric.water: ('Water', 'L', Icons.water_drop_outlined),
    _ChartMetric.nutrition: ('Nutrition', 'meals', Icons.restaurant_outlined),
    _ChartMetric.weight: ('Weight', 'kg', Icons.monitor_weight_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Health Trends', style: theme.textTheme.titleLarge),
                ),
                SegmentedButton<_ChartRange>(
                  key: const Key('healthChartRangeToggle'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _ChartRange.sevenDay, label: Text('7d')),
                    ButtonSegment(value: _ChartRange.thirtyDay, label: Text('30d')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final metric in _ChartMetric.values)
                  ChoiceChip(
                    key: Key('healthChartMetric${metric.name}'),
                    label: Text(_labels[metric]!.$1),
                    avatar: Icon(_labels[metric]!.$3, size: 18),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<_ChartMetric, List<_DayValue>>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final allSeries = snapshot.data?[_metric] ?? const <_DayValue>[];
                final days = _range == _ChartRange.sevenDay ? 7 : 30;
                final series = allSeries.sublist(allSeries.length - days);
                final (label, unit, _) = _labels[_metric]!;
                return _ChartBody(series: series, label: label, unit: unit);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.series, required this.label, required this.unit});

  final List<_DayValue> series;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnyData = series.any((d) => d.value != null);
    if (!hasAnyData) {
      return Padding(
        key: const Key('healthChartEmptyState'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Not enough $label data yet for this range — log a few more '
          'days to see a trend.',
        ),
      );
    }

    final latest = series.lastWhere((d) => d.value != null, orElse: () => series.last);
    final maxValue = series
        .map((d) => d.value ?? 0)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final isSparse = series.length > 10;
    // A 30-day axis showing every date would be unreadable on a phone --
    // thin the labels, but every day still gets its own bar slot.
    final labelEvery = isSparse ? (series.length / 6).ceil() : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          key: const Key('healthChartLatestValue'),
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Latest: '),
              TextSpan(
                text: '${_formatValue(latest.value!)} $unit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in series)
                Expanded(
                  child: Tooltip(
                    message: point.value == null
                        ? '${_formatDate(point.day)}: no data'
                        : '${_formatDate(point.day)}: ${_formatValue(point.value!)} $unit',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isSparse)
                            Text(
                              point.value == null ? '—' : _formatValue(point.value!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: point.value == null
                                    ? theme.colorScheme.outline
                                    : null,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: point.value == null
                                ? 4
                                : (8 + (point.value! / (maxValue == 0 ? 1 : maxValue)) * 70)
                                    .clamp(4, 80),
                            decoration: BoxDecoration(
                              color: point.value == null
                                  ? theme.colorScheme.outlineVariant
                                  : theme.colorScheme.primary.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < series.length; i++)
              Expanded(
                child: Text(
                  i % labelEvery == 0 ? _formatDate(series[i].day) : '',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _formatValue(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static String _formatDate(DateTime d) => '${d.month}/${d.day}';
}
