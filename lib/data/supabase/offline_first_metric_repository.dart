import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/metric_write_queue.dart';
import '../local/queued_write.dart';
import '../../domain/models/sync_status.dart';

/// Shared offline-first engine (contract 3) reused by every per-metric
/// repository: writes go to the local queue immediately and are synced by
/// [SyncService] in the background; reads go straight to Supabase, which is
/// safe because every table enforces `user_id = auth.uid()` RLS.
class OfflineFirstMetricRepository<T> {
  OfflineFirstMetricRepository({
    required SupabaseClient client,
    required MetricWriteQueue queue,
    required this.table,
    required this.toJson,
    required this.fromJson,
  })  : _client = client,
        _queue = queue;

  final SupabaseClient _client;
  final MetricWriteQueue _queue;
  final String table;
  final Map<String, dynamic> Function(T record) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  static final Uuid _uuid = Uuid();

  Future<void> log(T record) async {
    final json = toJson(record);
    final id = (json['id'] as String?) ?? _uuid.v4();
    json['id'] = id;
    final clientTimestamp = DateTime.now().toUtc();
    json['client_timestamp'] = clientTimestamp.toIso8601String();
    json['sync_status'] = SyncStatus.pending.name;
    await _queue.enqueue(QueuedWrite(
      clientId: id,
      table: table,
      payload: json,
      clientTimestamp: clientTimestamp,
    ));
  }

  Future<List<T>> recent({int days = 7}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await _client
        .from(table)
        .select()
        .gte('logged_at', since.toIso8601String())
        .order('logged_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
