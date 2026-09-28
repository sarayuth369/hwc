class UserProfile {
  const UserProfile({
    required this.userId,
    this.displayName,
    this.dateOfBirth,
    this.locale = 'en',
  });

  final String userId;
  final String? displayName;
  final DateTime? dateOfBirth;
  final String locale;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        dateOfBirth: json['date_of_birth'] == null
            ? null
            : DateTime.parse(json['date_of_birth'] as String),
        locale: json['locale'] as String? ?? 'en',
      );

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'display_name': displayName,
        if (dateOfBirth != null)
          'date_of_birth': dateOfBirth!.toIso8601String().split('T').first,
        'locale': locale,
      };
}
