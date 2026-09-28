/// Typed AI-chat failures with plain-language messages, so the UI never has
/// to parse strings or guess at server error codes to decide what to show.
sealed class AiChatFailure {
  const AiChatFailure(this.message);

  final String message;
}

class AiAuthFailure extends AiChatFailure {
  const AiAuthFailure([super.message = 'Please sign in again to use AI chat.']);
}

class AiNetworkFailure extends AiChatFailure {
  const AiNetworkFailure([
    super.message = 'Could not reach AI. Check your connection and try again.',
  ]);
}

class AiProviderFailure extends AiChatFailure {
  const AiProviderFailure([
    super.message = 'AI is unavailable right now. Try again in a moment.',
  ]);
}

/// A capability that genuinely doesn't exist on the server yet (e.g. voice
/// — the Worker's `NullVoiceProvider` returns a real 501). Carries the
/// server's own message so the UI states the honest gap rather than a
/// generic "try again" that implies the feature should eventually work on
/// retry.
class AiNotImplementedFailure extends AiChatFailure {
  const AiNotImplementedFailure([
    super.message = 'This isn\'t available yet.',
  ]);
}
