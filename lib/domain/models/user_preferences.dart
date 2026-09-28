class UserPreferences {
  const UserPreferences({
    required this.userId,
    this.seniorModeEnabled = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.unitsSystem = 'metric',
    this.notificationsEnabled = true,
  });

  final String userId;
  final bool seniorModeEnabled;
  final bool highContrast;
  final double textScale;
  final String unitsSystem;
  final bool notificationsEnabled;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        userId: json['user_id'] as String,
        seniorModeEnabled: json['senior_mode_enabled'] as bool? ?? false,
        highContrast: json['high_contrast'] as bool? ?? false,
        textScale: (json['text_scale'] as num?)?.toDouble() ?? 1.0,
        unitsSystem: json['units_system'] as String? ?? 'metric',
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'senior_mode_enabled': seniorModeEnabled,
        'high_contrast': highContrast,
        'text_scale': textScale,
        'units_system': unitsSystem,
        'notifications_enabled': notificationsEnabled,
      };
}
