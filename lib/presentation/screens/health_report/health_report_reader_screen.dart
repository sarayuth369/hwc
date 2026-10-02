import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/models/health_report_analysis.dart';
import '../../../domain/repositories/ai_repository.dart';

/// Health Report Reader: photo/upload a document, then a **two-step** real
/// AI read -- (1) the same vision endpoint the Food Scanner uses
/// (`/api/ai/image/analyze`, `purpose: "document"`) transcribes the visible
/// text/values, then (2) that transcription is sent through `/api/ai/chat`
/// with a structured-analysis prompt that explicitly separates what the
/// document *says* (extracted facts) from the AI's own plain-language
/// *interpretation* -- mirroring the Food Scanner's vision-then-estimate
/// pipeline so neither screen claims more precision than a general
/// vision-language model can honestly provide.
///
/// This is **not** a certified medical document extraction pipeline --
/// Workers AI's vision model is a general image-to-text model, not a
/// clinical OCR/data system, so results are best-effort and always carry
/// the disclaimer below. No diagnosis, prescription, or medication-change
/// suggestion is ever generated -- the prompts explicitly forbid it and
/// ask only for wellness-oriented suggestions and questions to bring to a
/// healthcare professional.
class HealthReportReaderScreen extends StatefulWidget {
  const HealthReportReaderScreen({super.key});

  @override
  State<HealthReportReaderScreen> createState() =>
      _HealthReportReaderScreenState();
}

class _HealthReportReaderScreenState extends State<HealthReportReaderScreen> {
  final _picker = ImagePicker();
  XFile? _photo;
  bool _isReading = false;
  bool _isAnalyzing = false;
  String? _rawText;
  HealthReportAnalysis? _analysis;
  AiChatFailure? _failure;

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return;
    setState(() {
      _photo = photo;
      _rawText = null;
      _analysis = null;
      _failure = null;
    });
    await _readReport(photo);
  }

  Future<void> _readReport(XFile photo) async {
    final aiRepository = context.read<AiRepository>();
    setState(() {
      _isReading = true;
      _failure = null;
    });
    String? transcription;
    try {
      final bytes = await photo.readAsBytes();
      final response = await aiRepository.analyzeImage({
        'imageBase64': base64Encode(bytes),
        'purpose': 'document',
      });
      if (!mounted) return;
      transcription = response['description'] as String?;
      setState(() => _rawText = transcription);
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
      return;
    } finally {
      if (mounted) setState(() => _isReading = false);
    }

    if (transcription == null || transcription.trim().isEmpty) return;
    await _analyzeText(transcription);
  }

  Future<void> _analyzeText(String transcription) async {
    final aiRepository = context.read<AiRepository>();
    setState(() {
      _isAnalyzing = true;
      _failure = null;
      _analysis = null;
    });
    try {
      final requestBody = {
        'message':
            'A health document was transcribed by an AI vision model as follows: '
            '"$transcription". Based ONLY on this text, respond with ONLY a '
            'compact JSON object, no other text, in exactly this shape: '
            '{"summary": string (what kind of document/what it covers), '
            '"extracted_values": string[] (specific values/results literally '
            'present in the text, e.g. "Glucose: 95 mg/dL" -- empty array if '
            'none), "observations": string[] (neutral factual observations '
            'about what is written -- empty array if none), "explanation": '
            'string (a plain-language explanation of what these kinds of '
            'values generally mean, for general education only), '
            '"suggestions": string[] (general wellness-oriented suggestions '
            'only -- never a specific treatment, dosage, or medication '
            'change), "questions_for_provider": string[] (questions the '
            'person could bring to a doctor or pharmacist), "confidence": '
            '"low" | "medium" | "high"}. '
            'Do not diagnose any disease or condition. Do not prescribe or '
            'recommend changing any medication. Do not invent values that '
            'are not present in the transcribed text. If the transcription '
            'is unclear or too incomplete to say anything useful, say so '
            'honestly in "summary" and use "low" confidence.',
        'healthContext': <String, dynamic>{},
      };
      Map<String, dynamic> response;
      try {
        response = await aiRepository.chat(requestBody);
      } on AiChatFailure catch (failure) {
        final transient = failure is AiProviderFailure ||
            failure is AiTimeoutFailure ||
            failure is AiRateLimitedFailure;
        if (!transient) rethrow;
        response = await aiRepository.chat(requestBody);
      }
      if (!mounted) return;
      final reply = response['reply'] as String? ?? '';
      setState(() => _analysis = HealthReportAnalysis.tryParse(reply));
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Health Report Reader')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This is an AI-assisted rough read, not a certified '
                        'medical interpretation. Always confirm results '
                        'with a healthcare professional.',
                        key: Key('healthReportDisclaimer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                              Icons.description_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Image.file(File(_photo!.path), fit: BoxFit.cover),
                  ),
                ),
                if (_isReading)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
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
                    key: const Key('healthReportCameraButton'),
                    onPressed:
                        (_isReading || _isAnalyzing) ? null : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('healthReportUploadButton'),
                    onPressed:
                        (_isReading || _isAnalyzing) ? null : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analyzing what was read...',
                    key: const Key('healthReportAnalyzingLabel'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (_failure != null) ...[
              const SizedBox(height: 16),
              Text(
                _failure!.message,
                key: const Key('healthReportErrorMessage'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_analysis != null) ...[
              const SizedBox(height: 16),
              _HealthReportAnalysisCard(analysis: _analysis!),
            ] else if (_rawText != null && !_isAnalyzing) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What we read', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(_rawText!, key: const Key('healthReportResultText')),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders the second-step structured analysis with extracted facts and
/// AI interpretation visually separated (distinct section headers, the
/// interpretation section visually set apart) so neither reads as a claim
/// that the AI verified anything beyond what the document literally says.
class _HealthReportAnalysisCard extends StatelessWidget {
  const _HealthReportAnalysisCard({required this.analysis});

  final HealthReportAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('healthReportAnalysisCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    analysis.summary,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${analysis.confidence} confidence',
                    key: const Key('healthReportConfidenceBadge'),
                    style: TextStyle(color: theme.colorScheme.tertiary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (analysis.extractedValues.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Values found in the document', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...analysis.extractedValues.map((v) => Text('• $v')),
            ],
            if (analysis.observations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Observations', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...analysis.observations.map((v) => Text('• $v')),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI interpretation (general education only)',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(analysis.explanation, key: const Key('healthReportExplanationText')),
                ],
              ),
            ),
            if (analysis.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('General wellness suggestions', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...analysis.suggestions.map((v) => Text('• $v')),
            ],
            if (analysis.questionsForProvider.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Questions to bring to your doctor', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...analysis.questionsForProvider.map((v) => Text('• $v')),
            ],
          ],
        ),
      ),
    );
  }
}
