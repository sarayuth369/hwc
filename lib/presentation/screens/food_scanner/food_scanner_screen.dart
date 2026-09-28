import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/ai/health_context.dart';
import '../../../core/nutrition/meal_type.dart';
import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/models/nutrition_record.dart';
import '../../../domain/repositories/ai_repository.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../../domain/repositories/profile_repository.dart';

/// Food Scanner: a **real** photo capture/pick flow, followed by an
/// **honest** AI-assisted nutrition estimate. There is no Vision AI
/// endpoint on the Worker today, so the photo is not analyzed by an image
/// model — instead, the user briefly describes what it is, and that
/// description goes through the already-real `/api/ai/chat` endpoint for a
/// plain-language calorie/macro estimate. This is documented in
/// `HWC_DECISIONS.md` as a deliberate choice, not a placeholder pretending
/// to be full image recognition.
class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  bool _isEstimating = false;
  bool _isSaving = false;
  String? _estimate;
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
      _failure = null;
      _saveMessage = null;
    });
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
      _saveMessage = null;
    });

    try {
      final healthContext = await buildHealthContext(profileRepository);
      final response = await aiRepository.chat({
        'message':
            'Give a brief, practical estimate of calories and macros '
            '(protein, carbs, fat) for this meal: "$description". '
            'Keep it short — this is a rough estimate, not exact.',
        'healthContext': healthContext,
      });
      if (!mounted) return;
      setState(() => _estimate = response['reply'] as String?);
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
                labelText: 'What is this?',
                hintText: 'e.g. Grilled chicken bowl',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI gives a rough estimate from your description — full photo '
              'analysis is not available yet.',
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
              Text(
                _failure!.message,
                key: const Key('foodScannerErrorMessage'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_estimate != null) ...[
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
