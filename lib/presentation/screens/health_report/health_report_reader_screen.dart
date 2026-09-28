import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/repositories/ai_repository.dart';

/// Health Report Reader: photo/upload a document, get a plain-English
/// read of the visible text via the same real vision endpoint the Food
/// Scanner uses (`/api/ai/image/analyze`, `purpose: "document"`). This is
/// **not** a certified medical document extraction pipeline — Workers AI's
/// vision model is a general image-to-text model, not a clinical OCR/data
/// system, so results are best-effort and always carry the disclaimer
/// below. No diagnosis, interpretation of medical meaning, or treatment
/// suggestions are ever generated here — the prompt explicitly asks the
/// model to describe what's written, not what it means.
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
  String? _result;
  AiChatFailure? _failure;

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return;
    setState(() {
      _photo = photo;
      _result = null;
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
    try {
      final bytes = await photo.readAsBytes();
      final response = await aiRepository.analyzeImage({
        'imageBase64': base64Encode(bytes),
        'purpose': 'document',
      });
      if (!mounted) return;
      setState(() => _result = response['description'] as String?);
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isReading = false);
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
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('healthReportUploadButton'),
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              Text(
                _failure!.message,
                key: const Key('healthReportErrorMessage'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What we read', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(_result!, key: const Key('healthReportResultText')),
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
