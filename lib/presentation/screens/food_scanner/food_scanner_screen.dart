import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/ai/health_context.dart';
import '../../../core/nutrition/meal_type.dart';
import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/models/nutrition_estimate.dart';
import '../../../domain/models/nutrition_record.dart';
import '../../../domain/repositories/ai_repository.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../../data/local/sync_service.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../widgets/confirmation_dialog.dart';

/// Food Scanner: real photo capture/pick, then **real** AI vision analysis
/// (the Worker's `/api/ai/image/analyze` route, backed by Cloudflare
/// Workers AI's `@cf/llava-hf/llava-1.5-7b-hf` model) auto-fills a
/// description of what's in the photo, which is then sent through the
/// existing `/api/ai/chat` endpoint for a nutrition estimate. The
/// description is editable — the vision model's output is prose, not
/// guaranteed-accurate structured data, so the user stays in control of
/// what actually gets estimated and logged.
class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  bool _isAnalyzingPhoto = false;
  bool _isEstimating = false;
  bool _isSaving = false;
  String? _estimate;
  NutritionEstimate? _structuredEstimate;
  AiChatFailure? _failure;
  String? _saveMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo == null) return;
    setState(() {
      _photo = photo;
      _estimate = null;
      _structuredEstimate = null;
      _failure = null;
      _saveMessage = null;
    });
    await _analyzePhoto(photo);
  }

  Future<void> _analyzePhoto(XFile photo) async {
    final aiRepository = context.read<AiRepository>();
    setState(() {
      _isAnalyzingPhoto = true;
      _failure = null;
    });
    try {
      final bytes = await photo.readAsBytes();
      final response = await aiRepository.analyzeImage({
        'imageBase64': base64Encode(bytes),
        'purpose': 'food',
      });
      if (!mounted) return;
      final description = response['description'] as String?;
      if (description != null && description.isNotEmpty) {
        _descriptionController.text = description;
      }
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isAnalyzingPhoto = false);
    }
  }

  Future<void> _estimateNutrition() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _failure = const AiProviderFailure(
            'Describe the meal first (e.g. "Grilled chicken bowl").',
          ));
      return;
    }

    final profileRepository = context.read<ProfileRepository>();
    final aiRepository = context.read<AiRepository>();

    setState(() {
      _isEstimating = true;
      _failure = null;
      _structuredEstimate = null;
      _saveMessage = null;
    });

    try {
      final healthContext = await buildHealthContext(profileRepository);
      final requestBody = {
        'message':
            'Give a nutrition estimate for this meal: "$description". '
            'Respond with ONLY a compact JSON object, no other text, in '
            'exactly this shape: {"dish": string, "confidence": '
            '"low" | "medium" | "high", "portion": string (e.g. "1 bowl, '
            '~350g"), "calories": number, "protein_g": number, "carbs_g": '
            'number, "fat_g": number, "notes": string (one short caveat)}. '
            'This is a rough estimate, not exact -- reflect that honestly '
            'in "confidence" and "notes" rather than overstating precision.',
        'healthContext': healthContext,
      };
      Map<String, dynamic> response;
      try {
        response = await aiRepository.chat(requestBody);
      } on AiProviderFailure {
        // Workers AI is a shared inference service with occasional
        // transient failures -- one silent retry before surfacing an
        // error avoids making the user manually retry for a hiccup that
        // clears up a second later (confirmed by direct testing against
        // the live Worker: the same request succeeds on a fresh attempt).
        response = await aiRepository.chat(requestBody);
      }
      if (!mounted) return;
      final reply = response['reply'] as String? ?? '';
      setState(() {
        _estimate = reply;
        // Tolerant: the chat endpoint has its own safety pre/post
        // processing and isn't a guaranteed structured-output API, so a
        // parse failure falls back to showing the raw reply as prose
        // (below) rather than crashing or inventing missing fields.
        _structuredEstimate = NutritionEstimate.tryParse(reply);
      });
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isEstimating = false);
    }
  }

  Future<void> _addToToday() async {
    final userId = context.read<CurrentUserService>().currentUserId;
    if (userId == null) {
      setState(() => _saveMessage = 'Sign in to log entries.');
      return;
    }
    final description = _descriptionController.text.trim();
    // The vision model's identification is a guess, not a verified fact
    // (see the on-device evidence in HWC_DECISIONS.md: a photographed guava
    // was misread as a kiwi/citrus fruit) -- require an explicit confirm of
    // exactly what will be logged, rather than saving whatever is still in
    // the editable field the moment the button is tapped.
    final structured = _structuredEstimate;
    final estimateSummary = structured != null
        ? '\n\n~${structured.calories.round()} kcal · '
            '${structured.proteinG.round()}g protein · '
            '${structured.carbsG.round()}g carbs · '
            '${structured.fatG.round()}g fat '
            '(${structured.confidence} confidence)'
        : (_estimate != null ? '\n\n$_estimate' : '');
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Add this to today?',
      message: description.isEmpty
          ? 'No description entered — this will be logged as "Scanned meal" with no nutrition estimate tied to it.'
          : 'Logging: "$description"'
              '$estimateSummary'
              '\n\nDouble-check the food name above is correct before adding — the AI\'s guess isn\'t always right.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isSaving = true);
    await context.read<NutritionRepository>().logNutrition(
          NutritionRecord(
            userId: userId,
            loggedAt: DateTime.now(),
            mealType: inferMealTypeFromTime(),
            description: description.isEmpty ? 'Scanned meal' : description,
          ),
        );
    if (!mounted) return;
    // Push the offline-first queue now rather than waiting for the next
    // up-to-30s sync tick, so Home/Health's "recent()" reads (straight
    // from Supabase) actually see it once this screen is popped.
    await context.read<MetricSyncTrigger>().syncPending();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveMessage = 'Added to today.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Food Scanner')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photo == null
                        ? Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Image.file(File(_photo!.path), fit: BoxFit.cover),
                  ),
                ),
                if (_isAnalyzingPhoto)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Looking at your photo...',
                              key: Key('foodScannerAnalyzingLabel'),
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('foodScannerCameraButton'),
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('foodScannerGalleryButton'),
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('foodScannerDescriptionField'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "AI's guess — edit if it's wrong",
                hintText: 'e.g. Grilled chicken bowl',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI reads your photo to guess what the food is — it can get '
              'this wrong, especially for less common fruits and '
              'vegetables. Correct the text above before estimating if it '
              "doesn't look right; the nutrition estimate is only as good "
              'as the food name.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('foodScannerEstimateButton'),
              onPressed: _isEstimating ? null : _estimateNutrition,
              child: _isEstimating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Estimate Nutrition'),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _failure!.message,
                      key: const Key('foodScannerErrorMessage'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  // A provider-side hiccup (Workers AI's shared inference
                  // service occasionally has transient failures) is often
                  // resolved by simply trying again -- matching AI Talk's
                  // existing retry pattern rather than leaving the user to
                  // discover "just tap Estimate Nutrition again" themselves.
                  if (_failure is! AiAuthFailure)
                    TextButton(
                      key: const Key('foodScannerRetryButton'),
                      onPressed: _isEstimating ? null : _estimateNutrition,
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ],
            if (_structuredEstimate != null) ...[
              const SizedBox(height: 16),
              _StructuredEstimateCard(estimate: _structuredEstimate!),
            ] else if (_estimate != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _estimate!,
                    key: const Key('foodScannerEstimateText'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('foodScannerAddToTodayButton'),
              onPressed: _isSaving ? null : _addToToday,
              icon: const Icon(Icons.add),
              label: const Text('Add to Today'),
            ),
            if (_saveMessage != null) ...[
              const SizedBox(height: 8),
              Text(_saveMessage!, key: const Key('foodScannerSaveMessage')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders the nutrition-estimate model's structured JSON reply as labeled
/// fields (portion/calories/macros) with a visible confidence badge and
/// caveat, instead of a single prose blob — this is still just an LLM's
/// estimate from a text description, never a claim that any model "saw"
/// the photo directly (the vision step is separate and unchanged).
class _StructuredEstimateCard extends StatelessWidget {
  const _StructuredEstimateCard({required this.estimate});

  final NutritionEstimate estimate;

  Color _confidenceColor(ColorScheme colors) => switch (estimate.confidence.toLowerCase()) {
        'high' => colors.secondary,
        'low' => colors.error,
        _ => colors.tertiary,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidenceColor = _confidenceColor(theme.colorScheme);
    return Card(
      key: const Key('foodScannerStructuredEstimate'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    estimate.dish,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${estimate.confidence} confidence',
                    key: const Key('foodScannerConfidenceBadge'),
                    style: TextStyle(color: confidenceColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(estimate.portion, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _MacroStat(label: 'Calories', value: '${estimate.calories.round()}'),
                _MacroStat(label: 'Protein', value: '${estimate.proteinG.round()}g'),
                _MacroStat(label: 'Carbs', value: '${estimate.carbsG.round()}g'),
                _MacroStat(label: 'Fat', value: '${estimate.fatG.round()}g'),
              ],
            ),
            if (estimate.notes != null && estimate.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                estimate.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
