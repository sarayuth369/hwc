import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/current_user_service.dart';

class CurrentUserServiceImpl implements CurrentUserService {
  CurrentUserServiceImpl(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;
}
