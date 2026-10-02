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

/// The request itself was rejected (bad/missing field, image too large,
/// malformed body) -- a 400 from the Worker, not a provider-side failure.
/// Retrying the exact same request won't help; the user needs to change
/// something (e.g. pick a smaller photo).
class AiInvalidRequestFailure extends AiChatFailure {
  const AiInvalidRequestFailure([
    super.message = "That request couldn't be processed. Please try a different photo or description.",
  ]);
}

/// The provider call itself timed out or hit a transport-level failure
/// (Cloudflare's own `3005 triton transport error`, for example) --
/// distinct from a generic provider error so the UI can suggest "try again"
/// with language that matches what actually happened.
class AiTimeoutFailure extends AiChatFailure {
  const AiTimeoutFailure([
    super.message = 'That took too long. Please try again.',
  ]);
}

/// The provider is temporarily rate-limited/over quota -- retrying
/// immediately is unlikely to help; a short wait is.
class AiRateLimitedFailure extends AiChatFailure {
  const AiRateLimitedFailure([
    super.message = 'AI is busy right now. Please try again shortly.',
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
