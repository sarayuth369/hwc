/// Read-only projection of `daily_health_summary`. Every field here is
/// computed by the `compute_wellness_score_v1` Postgres function — this
/// model never derives or adjusts the score client-side (contract 2).
class WellnessSummary {
  const WellnessSummary({
    required this.summaryDate,
    required this.wellnessScore,
    required this.scoreVersion,
    required this.componentScores,
    required this.explanation,
  });

  final DateTime summaryDate;
  final int? wellnessScore;
  final int? scoreVersion;
  final Map<String, dynamic> componentScores;
  final List<Map<String, dynamic>> explanation;

  factory WellnessSummary.fromJson(Map<String, dynamic> json) =>
      WellnessSummary(
        summaryDate: DateTime.parse(json['summary_date'] as String),
        wellnessScore: json['wellness_score'] as int?,
        scoreVersion: json['score_version'] as int?,
        componentScores: json['component_scores'] == null
            ? const {}
            : Map<String, dynamic>.from(json['component_scores'] as Map),
        explanation: json['explanation'] == null
            ? const []
            : List<Map<String, dynamic>>.from(
                (json['explanation'] as List<dynamic>)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              ),
      );
}
