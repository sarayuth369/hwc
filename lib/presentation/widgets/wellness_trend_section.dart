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
                        Builder(
                          builder: (context) {
                            // Same fix as WellnessScoreCard (real-device
                            // evidence showed this arriving as an all-zero
                            // componentScores map, not an empty one, for a
                            // no-data day) -- a zero score with no non-zero
                            // component reads as "no entry" (a dash, no
                            // bar), not as a real 0 day among six real ones.
                            final hasData = summary.wellnessScore != null &&
                                summary.wellnessScore != 0 &&
                                summary.componentScores.isNotEmpty;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      hasData
                                          ? '${summary.wellnessScore}'
                                          : '—',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: hasData
                                            ? null
                                            : theme.colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: hasData
                                          ? ((summary.wellnessScore ?? 0)
                                                  .clamp(0, 100) /
                                              100 *
                                              60)
                                          : 4,
                                      decoration: BoxDecoration(
                                        color: hasData
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.6)
                                            : theme.colorScheme.outlineVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
