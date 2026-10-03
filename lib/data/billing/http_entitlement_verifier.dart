import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../../domain/billing/entitlement_verifier.dart';
import '../../domain/repositories/current_user_service.dart';

/// Sends the Play purchase token to the Worker, which verifies it with the
/// Google Play Developer API and records the entitlement in Supabase. Carries
/// only the user's own Supabase access token -- no server secret ever lives
/// in the app.
class HttpEntitlementVerifier implements EntitlementVerifier {
  HttpEntitlementVerifier({
    required CurrentUserService currentUserService,
    http.Client? client,
  })  : _currentUserService = currentUserService,
        _client = client ?? http.Client();

  final CurrentUserService _currentUserService;
  final http.Client _client;

  static const _timeout = Duration(seconds: 25);

  @override
  Future<VerificationOutcome> verify({
    required String purchaseToken,
    required String productId,
  }) async {
    final accessToken = _currentUserService.accessToken;
    if (accessToken == null) return VerificationOutcome.unauthenticated;

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${Env.workerBaseUrl}/api/billing/google-play/verify'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'purchaseToken': purchaseToken,
              'productId': productId,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Offline, DNS failure, timeout: says nothing about entitlement.
      return VerificationOutcome.unavailable;
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    switch (response.statusCode) {
      case 200:
        if (body == null) return VerificationOutcome.unavailable;
        if (body['tier'] == 'premium') return VerificationOutcome.entitled;
        return body['status'] == 'pending_provider'
            ? VerificationOutcome.pending
            : VerificationOutcome.notEntitled;
      case 401:
        return VerificationOutcome.unauthenticated;
      case 403:
      case 422:
        return VerificationOutcome.rejected;
      case 503:
        return body?['code'] == 'billing_not_configured'
            ? VerificationOutcome.notConfigured
            : VerificationOutcome.unavailable;
      default:
        return VerificationOutcome.unavailable;
    }
  }
}
