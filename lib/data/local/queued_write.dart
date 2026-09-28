import 'dart:convert';
import '../../domain/models/sync_status.dart';

/// A single pending write to a Supabase table, queued locally before any
/// network call is made. Contract 3 (offline-first): every metric write
/// goes through this queue first.
class QueuedWrite {
  QueuedWrite({
    required this.clientId,
    required this.table,
    required this.payload,
    required this.clientTimestamp,
    this.syncStatus = SyncStatus.pending,
  });

  final String clientId;
  final String table;
  final Map<String, dynamic> payload;
  final DateTime clientTimestamp;
  final SyncStatus syncStatus;

  QueuedWrite copyWith({SyncStatus? syncStatus}) => QueuedWrite(
        clientId: clientId,
        table: table,
        payload: payload,
        clientTimestamp: clientTimestamp,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'table': table,
        'payload': payload,
        'clientTimestamp': clientTimestamp.toIso8601String(),
        'syncStatus': syncStatus.name,
      };

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite(
        clientId: json['clientId'] as String,
        table: json['table'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        clientTimestamp: DateTime.parse(json['clientTimestamp'] as String),
        syncStatus: SyncStatus.values.byName(json['syncStatus'] as String),
      );

  static String encodeList(List<QueuedWrite> writes) =>
      jsonEncode(writes.map((w) => w.toJson()).toList());

  static List<QueuedWrite> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => QueuedWrite.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
