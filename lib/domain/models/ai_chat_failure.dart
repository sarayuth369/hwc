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
