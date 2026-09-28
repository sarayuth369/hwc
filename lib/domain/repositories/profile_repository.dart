import '../models/user_profile.dart';
import '../models/user_preferences.dart';

abstract class ProfileRepository {
  Future<UserProfile?> fetchProfile();
  Future<void> updateDisplayName(String displayName);
  Future<UserPreferences?> fetchPreferences();
  Future<void> updatePreferences(UserPreferences preferences);
}
