import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<UserProfile?> fetchProfile() async {
    final userId = _userId;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromJson(row);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'display_name': displayName}).eq('user_id', userId);
  }

  @override
  Future<UserPreferences?> fetchPreferences() async {
    final userId = _userId;
    if (userId == null) return null;
    final row = await _client
        .from('user_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : UserPreferences.fromJson(row);
  }

  @override
  Future<void> updatePreferences(UserPreferences preferences) async {
    await _client.from('user_preferences').upsert(preferences.toJson());
  }
}
