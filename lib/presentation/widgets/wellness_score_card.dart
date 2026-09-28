import 'package:flutter/material.dart';
import '../../domain/models/wellness_summary.dart';

/// Renders whatever [WellnessSummary] the `compute_wellness_score_v1`
/// Postgres function returned. No score math happens in this widget.
class WellnessScoreCard extends StatelessWidget {
  const WellnessScoreCard({required this.summary, super.key});

  final WellnessSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null || summary.wellnessScore == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Log a few metrics today to see your Wellness Score.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.wellnessScore}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('Wellness Score'),
            const SizedBox(height: 12),
            for (final component in summary.explanation)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${component['component']}: ${component['note'] ?? ''}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
