import '../../domain/repositories/profile_repository.dart';

/// Builds the minimal `healthContext` map the Worker's
/// `HealthContextValidator` allow-lists (age, gender, etc.) — currently
/// only `age`, derived from the profile's date of birth when set. Shared by
/// AI Talk and the Home "Today's Insight" card so both send the same shape.
Future<Map<String, dynamic>> buildHealthContext(
  ProfileRepository profileRepository,
) async {
  final profile = await profileRepository.fetchProfile();
  final dateOfBirth = profile?.dateOfBirth;
  if (dateOfBirth == null) return {};
  final now = DateTime.now();
  var age = now.year - dateOfBirth.year;
  final hasHadBirthdayThisYear = now.month > dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
  if (!hasHadBirthdayThisYear) age -= 1;
  return {'age': age};
}
