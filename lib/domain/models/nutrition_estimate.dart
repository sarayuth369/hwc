import 'dart:convert';

/// A structured nutrition estimate parsed from the AI chat model's reply.
/// The model is asked to return JSON, but it's a general chat endpoint
/// (with safety pre/post-processing that can rewrite the reply text), not
/// a guaranteed structured-output API -- [tryParse] is deliberately
/// tolerant and returns `null` on anything that doesn't parse cleanly, so
/// the UI can fall back to showing the raw reply as plain prose rather
/// than crash or fabricate missing fields.
class NutritionEstimate {
  const NutritionEstimate({
    required this.dish,
    required this.confidence,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.notes,
  });

  final String dish;
  final String confidence;
  final String portion;
  final num calories;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final String? notes;

  static NutritionEstimate? tryParse(String raw) {
    final jsonStart = raw.indexOf('{');
    final jsonEnd = raw.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) return null;
    try {
      final decoded = jsonDecode(raw.substring(jsonStart, jsonEnd + 1));
      if (decoded is! Map) return null;
      final dish = decoded['dish'];
      final confidence = decoded['confidence'];
      final portion = decoded['portion'];
      final calories = decoded['calories'];
      final protein = decoded['protein_g'];
      final carbs = decoded['carbs_g'];
      final fat = decoded['fat_g'];
      if (dish is! String ||
          confidence is! String ||
          portion is! String ||
          calories is! num ||
          protein is! num ||
          carbs is! num ||
          fat is! num) {
        return null;
      }
      return NutritionEstimate(
        dish: dish,
        confidence: confidence,
        portion: portion,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        notes: decoded['notes'] is String ? decoded['notes'] as String : null,
      );
    } catch (_) {
      return null;
    }
  }
}
