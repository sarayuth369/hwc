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
          .timeout(_timeout);
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
    if (response.statusCode >= 400) {
      throw const AiProviderFailure();
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
