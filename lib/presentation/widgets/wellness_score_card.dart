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
    if (summary == null || summary.wellnessScore == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Log a few metrics today to see your Wellness Score.'),
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
}

class _ScoreBand {
  const _ScoreBand(this.label, this.color);

  final String label;
  final Color color;

  factory _ScoreBand.forScore(int score, ColorScheme colors) {
    if (score >= 75) return _ScoreBand('GOOD', colors.secondary);
    if (score >= 50) return _ScoreBand('FAIR', colors.tertiary);
    return _ScoreBand('NEEDS CARE', colors.error);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
