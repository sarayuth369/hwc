import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../../domain/models/ai_chat_failure.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/repositories/current_user_service.dart';

/// Calls only the documented Worker routes (contract 1). No vendor name,
/// API key, or provider branching lives here — that is Worker B's
/// responsibility inside `bkknex-worker`. Every request carries the signed-in
/// user's own Supabase access token; no server-side secret ever lives here.
class HttpAiRepository implements AiRepository {
  HttpAiRepository({
    required CurrentUserService currentUserService,
    http.Client? client,
  })  : _currentUserService = currentUserService,
        _client = client ?? http.Client();

  final CurrentUserService _currentUserService;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);
  // Vision inference is slower than text chat.
  static const _imageTimeout = Duration(seconds: 40);

  @override
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody) =>
      _post('/api/ai/chat', requestBody);

  @override
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody) =>
      _post('/api/ai/insight', requestBody);

  @override
  Future<Map<String, dynamic>> analyzeImage(Map<String, dynamic> requestBody) =>
      _post('/api/ai/image/analyze', requestBody, timeout: _imageTimeout);

  @override
  Future<Map<String, dynamic>> transcribeVoice(Map<String, dynamic> requestBody) =>
      _post('/api/ai/voice/transcribe', requestBody);

  @override
  Future<Map<String, dynamic>> synthesizeVoice(Map<String, dynamic> requestBody) =>
      _post('/api/ai/voice/synthesize', requestBody);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final token = _currentUserService.accessToken;
    if (token == null) {
      throw const AiAuthFailure();
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${Env.workerBaseUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw const AiNetworkFailure();
    } on SocketException {
      throw const AiNetworkFailure();
    } on http.ClientException {
      throw const AiNetworkFailure();
    }

    if (response.statusCode == 401) {
      throw const AiAuthFailure();
    }
    if (response.statusCode == 501) {
      throw AiNotImplementedFailure(_serverMessage(response) ?? 'This isn\'t available yet.');
    }
    if (response.statusCode >= 400) {
      throw const AiProviderFailure();
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _serverMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Fall through to null — use the caller's default message.
    }
    return null;
  }
}
