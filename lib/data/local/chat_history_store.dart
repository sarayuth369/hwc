import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/chat_message.dart';

/// Local-only AI Talk history so a conversation survives an app restart.
/// No backend conversation storage exists — this never leaves the device.
class ChatHistoryStore {
  ChatHistoryStore(this._prefs);

  static const _messagesKey = 'ai_chat_history_v1';
  static const _conversationIdKey = 'ai_chat_conversation_id_v1';

  final SharedPreferences _prefs;

  List<ChatMessage> loadMessages() {
    final raw = _prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMessages(List<ChatMessage> messages) =>
      _prefs.setString(
        _messagesKey,
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );

  String? loadConversationId() => _prefs.getString(_conversationIdKey);

  Future<void> saveConversationId(String? id) async {
    if (id == null) {
      await _prefs.remove(_conversationIdKey);
    } else {
      await _prefs.setString(_conversationIdKey, id);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_messagesKey);
    await _prefs.remove(_conversationIdKey);
  }
}
