import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/push/push_ports.dart';

/// Writes go through two SECURITY DEFINER RPCs (see
/// `supabase/migrations/0005_push_tokens.sql`): `push_tokens` has no
/// client INSERT/UPDATE/DELETE policy at all, so a client can only ever
/// register or deactivate tokens *as the signed-in user* -- never touch
/// another user's rows.
class PushTokenRepositoryImpl implements PushTokenRepository {
  PushTokenRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String deviceId,
    required String appVersion,
  }) async {
    await _client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': platform,
      'p_device_id': deviceId,
      'p_app_version': appVersion,
    });
  }

  @override
  Future<void> deactivate(String token) async {
    await _client.rpc('deactivate_push_token', params: {'p_token': token});
  }
}
