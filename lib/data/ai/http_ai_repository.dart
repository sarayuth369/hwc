import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/env.dart';
import '../../domain/repositories/ai_repository.dart';

/// Calls only the documented Worker routes (contract 1). No vendor name,
/// API key, or provider branching lives here — that is Worker B's
/// responsibility inside `bkknex-worker`.
class HttpAiRepository implements AiRepository {
  HttpAiRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody) =>
      _post('/api/ai/chat', requestBody);

  @override
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody) =>
      _post('/api/ai/insight', requestBody);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('${Env.workerBaseUrl}$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
