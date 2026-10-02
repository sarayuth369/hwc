import 'dart:convert';

/// A structured read of a health document/report, parsed from the AI chat
/// model's reply. Mirrors [NutritionEstimate]'s tolerant-parse pattern: the
/// model is asked for JSON but the chat endpoint isn't a guaranteed
/// structured-output API, so [tryParse] returns `null` on anything that
/// doesn't parse cleanly and the UI falls back to raw prose instead of
/// crashing or inventing missing fields.
///
/// Deliberately separates [extractedValues]/[observations] (what the
/// document says) from [explanation]/[suggestions] (the AI's own
/// interpretation) -- the one-shot spec requires this distinction so the
/// UI never presents an AI inference as if it were a fact read off the
/// page.
class HealthReportAnalysis {
  const HealthReportAnalysis({
    required this.summary,
    required this.extractedValues,
    required this.observations,
    required this.explanation,
    required this.suggestions,
    required this.questionsForProvider,
    required this.confidence,
  });

  final String summary;
  final List<String> extractedValues;
  final List<String> observations;
  final String explanation;
  final List<String> suggestions;
  final List<String> questionsForProvider;
  final String confidence;

  static HealthReportAnalysis? tryParse(String raw) {
    final jsonStart = raw.indexOf('{');
    final jsonEnd = raw.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) return null;
    try {
      final decoded = jsonDecode(raw.substring(jsonStart, jsonEnd + 1));
      if (decoded is! Map) return null;
      final summary = decoded['summary'];
      final explanation = decoded['explanation'];
      final confidence = decoded['confidence'];
      if (summary is! String || explanation is! String || confidence is! String) {
        return null;
      }
      return HealthReportAnalysis(
        summary: summary,
        extractedValues: _stringList(decoded['extracted_values']),
        observations: _stringList(decoded['observations']),
        explanation: explanation,
        suggestions: _stringList(decoded['suggestions']),
        questionsForProvider: _stringList(decoded['questions_for_provider']),
        confidence: confidence,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }
}
