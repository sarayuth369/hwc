class WaterRecord {
  const WaterRecord({
    this.id,
    required this.userId,
    required this.loggedAt,
    required this.amountMl,
  });

  final String? id;
  final String userId;
  final DateTime loggedAt;
  final int amountMl;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'logged_at': loggedAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory WaterRecord.fromJson(Map<String, dynamic> json) => WaterRecord(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}
