import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/repositories/ai_repository.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/profile_repository.dart';

/// A calm, single-question AI chat entry point (contract 1: the client only
/// ever calls the Worker's documented `/api/ai/chat` route and relays what
/// it returns — no safety logic, diagnosis, or prescribing happens here).
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _reply;
  bool _requiresProfessionalCare = false;
  AiChatFailure? _failure;
  String? _lastMessage;
  String? _conversationId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _buildHealthContext(
    ProfileRepository profileRepository,
  ) async {
    final profile = await profileRepository.fetchProfile();
    final dateOfBirth = profile?.dateOfBirth;
    if (dateOfBirth == null) return {};
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    final hasHadBirthdayThisYear = now.month > dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!hasHadBirthdayThisYear) age -= 1;
    return {'age': age};
  }

  Future<void> _send([String? message]) async {
    final text = message ?? _controller.text.trim();
    if (text.isEmpty) return;

    final profileRepository = context.read<ProfileRepository>();
    final aiRepository = context.read<AiRepository>();

    setState(() {
      _isLoading = true;
      _failure = null;
      _lastMessage = text;
    });

    try {
      final healthContext = await _buildHealthContext(profileRepository);
      final response = await aiRepository.chat({
        if (_conversationId != null) 'conversationId': _conversationId,
        'message': text,
        'healthContext': healthContext,
      });
      if (!mounted) return;
      final safetyFlag = response['safetyFlag'] as Map<String, dynamic>?;
      setState(() {
        _reply = response['reply'] as String?;
        _conversationId = response['conversationId'] as String?;
        _requiresProfessionalCare =
            safetyFlag?['requiresProfessionalCare'] == true;
        _controller.clear();
      });
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<CurrentUserService>().currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask AI')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: userId == null
            ? const Text(
                'Sign in to use AI chat.',
                key: Key('aiChatSignInMessage'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_reply != null) ...[
                    Text(_reply!, key: const Key('aiChatReply')),
                    if (_requiresProfessionalCare) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'This may need a healthcare professional. '
                        'Please consider talking to one.',
                        key: Key('aiChatProfessionalCareNotice'),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (_failure != null) ...[
                    Text(
                      _failure!.message,
                      key: const Key('aiChatErrorMessage'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('aiChatRetryButton'),
                      onPressed: _lastMessage == null
                          ? null
                          : () => _send(_lastMessage),
                      child: const Text('Try again'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    key: const Key('aiChatInput'),
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Ask a question',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('aiChatSendButton'),
                    onPressed: _isLoading ? null : () => _send(),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
      ),
    );
  }
}
