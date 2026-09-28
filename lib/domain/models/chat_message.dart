/// One turn in an AI Talk conversation, persisted locally so history
/// survives an app restart (there is no server-side conversation storage
/// today — this is a client-only convenience, not a backend feature).
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.requiresProfessionalCare = false,
  });

  final String text;
  final bool fromUser;
  final bool requiresProfessionalCare;

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'requiresProfessionalCare': requiresProfessionalCare,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String? ?? '',
        fromUser: json['fromUser'] as bool? ?? false,
        requiresProfessionalCare:
            json['requiresProfessionalCare'] as bool? ?? false,
      );
}
