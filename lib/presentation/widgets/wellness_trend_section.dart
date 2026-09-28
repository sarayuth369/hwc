import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/wellness_summary.dart';
import '../../domain/repositories/daily_summary_repository.dart';

/// A simple 7-day Wellness Score trend — bars sized by score, oldest to
/// newest. Reuses the existing `summaryFor` RPC (via `recentSummaries`, one
/// call per day) rather than a new backend aggregation endpoint.
class WellnessTrendSection extends StatefulWidget {
  const WellnessTrendSection({super.key});

  @override
  State<WellnessTrendSection> createState() => _WellnessTrendSectionState();
}

class _WellnessTrendSectionState extends State<WellnessTrendSection> {
  late final Future<List<WellnessSummary>> _trendFuture =
      context.read<DailySummaryRepository>().recentSummaries(days: 7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7-Day Trend', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<WellnessSummary>>(
              future: _trendFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final trend = snapshot.data ?? const [];
                if (trend.isEmpty) {
                  return const Text('Not enough data yet for a trend.');
                }
                return SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final summary in trend)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${summary.wellnessScore ?? '-'}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: ((summary.wellnessScore ?? 0)
                                          .clamp(0, 100) /
                                      100 *
                                      60),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
