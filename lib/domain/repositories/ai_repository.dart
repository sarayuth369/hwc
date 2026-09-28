/// Contract 1 (AI provider abstraction): the Flutter client only ever calls
/// these routes on the Worker (`bkknex-worker`, owned by Worker B). No
/// vendor name, provider branching, or voice-vendor logic belongs here or
/// anywhere else in this app — that all lives server-side on the Worker.
/// Not wired into any screen yet; Phase 2 wires the chat UI to this seam
/// once the `/api/ai/chat` contract is confirmed with Worker B.
abstract class AiRepository {
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody);
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody);
}
