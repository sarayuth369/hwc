/// Contract 1 (AI provider abstraction): the Flutter client only ever calls
/// these routes on the Worker (`bkknex-worker`, owned by Worker B). No
/// vendor name, provider branching, or voice-vendor logic belongs here or
/// anywhere else in this app — that all lives server-side on the Worker.
/// Not wired into any screen yet; Phase 2 wires the chat UI to this seam
/// once the `/api/ai/chat` contract is confirmed with Worker B.
abstract class AiRepository {
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody);
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody);

  /// Real Workers AI vision analysis (`/api/ai/image/analyze`) — used by
  /// the Food Scanner and Health Report Reader. `requestBody` is
  /// `{imageBase64, purpose: "food"|"document"}`; the response is
  /// `{description}`.
  Future<Map<String, dynamic>> analyzeImage(Map<String, dynamic> requestBody);

  /// Voice input/output seam. The Worker's voice provider is a documented
  /// no-op today (`NullVoiceProvider`), so these currently resolve to a
  /// real 501 from the server — this is intentionally wired to the real
  /// endpoint rather than left unimplemented, so the UI shows an honest
  /// server-sourced "not available yet" message instead of a dead button.
  Future<Map<String, dynamic>> transcribeVoice(Map<String, dynamic> requestBody);
  Future<Map<String, dynamic>> synthesizeVoice(Map<String, dynamic> requestBody);
}
