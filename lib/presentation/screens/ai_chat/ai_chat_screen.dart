import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/ai/health_context.dart';
import '../../../data/local/chat_history_store.dart';
import '../../../domain/models/ai_chat_failure.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/repositories/ai_repository.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/profile_repository.dart';

const _suggestedPrompts = [
  'Is this food good for me?',
  'How can I sleep better?',
  'What should I eat today?',
  'Create a walking plan for me',
];

/// A calm chat-bubble AI Talk screen (contract 1: the client only ever
/// calls the Worker's documented `/api/ai/chat` route and relays what it
/// returns — no safety logic, diagnosis, or prescribing happens here).
/// History is persisted locally (`ChatHistoryStore`) so a conversation
/// survives an app restart — there is no server-side conversation storage.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _isLoading = false;
  AiChatFailure? _failure;
  String? _lastMessage;
  String? _conversationId;
  bool _historyLoaded = false;
  bool _speechInitialized = false;
  bool _isListening = false;
  String? _voiceError;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    unawaited(_speech.stop());
    unawaited(_tts.stop());
    super.dispose();
  }

  void _loadHistoryOnce(ChatHistoryStore store) {
    if (_historyLoaded) return;
    _historyLoaded = true;
    final saved = store.loadMessages();
    if (saved.isEmpty) return;
    _messages.addAll(saved);
    _conversationId = store.loadConversationId();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _newConversation(ChatHistoryStore store) async {
    setState(() {
      _messages.clear();
      _conversationId = null;
      _failure = null;
      _lastMessage = null;
    });
    await store.clear();
  }

  /// Real on-device speech-to-text (Android's built-in speech recognizer
  /// via the `speech_to_text` plugin) — no backend/account/secret needed,
  /// unlike the Worker's still-unimplemented `/api/ai/voice/*` routes. Tap
  /// to start listening, tap again (or wait for a pause) to stop; the
  /// recognized text is sent through the same real `/api/ai/chat` flow as
  /// typed messages.
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechInitialized) {
      // `initialize()` only ever completes via a native->Dart status
      // callback -- if the OS speech service is unavailable/misbehaving
      // (or, in `flutter test`, simply absent) it never fires and the
      // Future hangs forever with no error. A bounded timeout turns that
      // into a real, recoverable "voice isn't available" state instead of
      // leaving the mic button stuck indefinitely.
      try {
        _speechInitialized = await _speech
            .initialize(
              onError: (error) {
                if (!mounted) return;
                setState(() {
                  _isListening = false;
                  _voiceError = 'Voice error: ${error.errorMsg}';
                });
              },
              onStatus: (status) {
                if (!mounted) return;
                if (status == 'notListening' || status == 'done') {
                  setState(() => _isListening = false);
                }
              },
            )
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
      } catch (_) {
        _speechInitialized = false;
      }
    }

    if (!_speechInitialized) {
      if (!mounted) return;
      setState(() {
        _voiceError = "Voice isn't available — check the microphone "
            'permission for this app in system settings.';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _voiceError = null;
    });
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        if (result.finalResult) {
          setState(() => _isListening = false);
          final heard = result.recognizedWords.trim();
          if (heard.isNotEmpty) _send(heard);
        }
      },
    );
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _send([String? message]) async {
    final text = message ?? _controller.text.trim();
    if (text.isEmpty) return;

    final profileRepository = context.read<ProfileRepository>();
    final aiRepository = context.read<AiRepository>();
    final historyStore = context.read<ChatHistoryStore>();

    setState(() {
      _isLoading = true;
      _failure = null;
      _lastMessage = text;
      _messages.add(ChatMessage(text: text, fromUser: true));
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final healthContext = await buildHealthContext(profileRepository);
      final response = await aiRepository.chat({
        if (_conversationId != null) 'conversationId': _conversationId,
        'message': text,
        'healthContext': healthContext,
      });
      if (!mounted) return;
      final safetyFlag = response['safetyFlag'] as Map<String, dynamic>?;
      setState(() {
        _conversationId = response['conversationId'] as String?;
        _messages.add(ChatMessage(
          text: response['reply'] as String? ?? '',
          fromUser: false,
          requiresProfessionalCare:
              safetyFlag?['requiresProfessionalCare'] == true,
        ));
      });
      _scrollToEnd();
      await historyStore.saveMessages(_messages);
      await historyStore.saveConversationId(_conversationId);
    } on AiChatFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.read<CurrentUserService>().currentUserId;

    if (userId == null) {
      return const Center(
        child: Text(
          'Sign in to use AI chat.',
          key: Key('aiChatSignInMessage'),
        ),
      );
    }

    _loadHistoryOnce(context.read<ChatHistoryStore>());

    return Column(
      children: [
        if (_messages.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('aiChatNewConversationButton'),
              onPressed: () => _newConversation(context.read<ChatHistoryStore>()),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('New conversation'),
            ),
          ),
        Expanded(
          child: _messages.isEmpty
              ? _EmptyState(onPromptTap: (prompt) => _send(prompt))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _MessageBubble(
                      message: message,
                      onSpeak: message.fromUser
                          ? null
                          : () => _speak(message.text),
                    );
                  },
                ),
        ),
        if (_voiceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _voiceError!,
              key: const Key('aiChatVoiceErrorMessage'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _failure!.message,
                    key: const Key('aiChatErrorMessage'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  key: const Key('aiChatRetryButton'),
                  onPressed: _lastMessage == null ? null : () => _send(_lastMessage),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  key: const Key('aiChatVoiceButton'),
                  onPressed: _isLoading ? null : _toggleListening,
                  tooltip: _isListening ? 'Stop listening' : 'Voice',
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? theme.colorScheme.error : null,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('aiChatInput'),
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Ask a question',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        key: const Key('aiChatSendButton'),
                        onPressed: () => _send(),
                        icon: Icon(Icons.send, color: theme.colorScheme.primary),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('How can I help you today?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final prompt in _suggestedPrompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => onPromptTap(prompt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onSpeak});

  final ChatMessage message;

  /// Reads this message aloud via on-device text-to-speech — only ever
  /// passed for an AI reply (never a user's own message).
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.fromUser;
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                key: isUser ? null : const Key('aiChatReply'),
                style: TextStyle(
                  color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
              ),
              if (onSpeak != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('aiChatSpeakButton'),
                    onPressed: onSpeak,
                    tooltip: 'Read aloud',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.volume_up_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (message.requiresProfessionalCare)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'This may need a healthcare professional. Please consider talking to one.',
              key: const Key('aiChatProfessionalCareNotice'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
