import 'package:flutter/material.dart';
import '../../domain/models/wellness_summary.dart';

/// Renders whatever [WellnessSummary] the `compute_wellness_score_v1`
/// Postgres function returned. No score math happens in this widget — the
/// color band below is presentation only (a threshold on the already-
/// computed score), never a re-derivation of it.
class WellnessScoreCard extends StatelessWidget {
  const WellnessScoreCard({required this.summary, super.key});

  final WellnessSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = this.summary;
    // Real-device evidence (2026-09-30 polish pass) showed a brand-new,
    // never-logged-anything account still rendering "0 / NEEDS CARE" —
    // disproving the earlier assumption (based only on the RPC's own SQL
    // test fixtures, never verified against live production output) that
    // `component_scores` is reliably sparse/empty for a no-data day. In
    // production it can arrive as an all-zero map rather than an omitted
    // one. Treating a zero score with no non-zero component as "no data"
    // is deliberately the more inclusive (and safer) reading: a genuinely
    // bad real day would need every single tracked metric (sleep, activity,
    // water, nutrition) to have been actually logged as a real zero on the
    // same day, which is implausible next to "the RPC's default/no-data
    // case is zero" — and mislabeling a brand-new user as "NEEDS CARE" is
    // the worse failure mode the product explicitly wants to avoid.
    final hasAnyRealData = summary != null &&
        summary.wellnessScore != null &&
        summary.wellnessScore != 0 &&
        summary.componentScores.isNotEmpty;
    if (summary == null || summary.wellnessScore == null || !hasAnyRealData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.spa_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Let's build your baseline — log a metric to see your Wellness Score.",
                  key: Key('wellnessScoreNeutralState'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final score = summary.wellnessScore!;
    final band = _ScoreBand.forScore(score, theme.colorScheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Wellness Score',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$score',
                        key: const Key('wellnessScoreValue'),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: band.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    band.label,
                    key: const Key('wellnessScoreBand'),
                    style: TextStyle(
                      color: band.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              band.meaning,
              key: const Key('wellnessScoreMeaning'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Based on today\'s ${_contributingMetrics(summary.componentScores.keys)}',
              key: const Key('wellnessScoreContributors'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (summary.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                summary.explanation
                    .map((c) => c['note'])
                    .whereType<String>()
                    .firstOrNull ??
                    '',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _contributingMetrics(Iterable<String> keys) {
    const labels = {
      'sleep': 'Sleep',
      'activity': 'Activity',
      'water': 'Water',
      'nutrition': 'Nutrition',
    };
    final names = keys.map((k) => labels[k] ?? k).toList();
    if (names.isEmpty) return 'logged metrics';
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}

class _ScoreBand {
  const _ScoreBand(this.label, this.color, this.meaning);

  final String label;
  final Color color;
  final String meaning;

  factory _ScoreBand.forScore(int score, ColorScheme colors) {
    if (score >= 75) {
      return _ScoreBand('GOOD', colors.secondary, "You're doing great today.");
    }
    if (score >= 50) {
      return _ScoreBand(
        'FAIR',
        colors.tertiary,
        'A solid day — a bit more balance could help.',
      );
    }
    return _ScoreBand(
      'NEEDS CARE',
      colors.error,
      "Today's numbers suggest your body could use more rest, movement, or water.",
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
