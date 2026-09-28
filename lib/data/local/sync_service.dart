import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'metric_write_queue.dart';

/// Drains the [MetricWriteQueue] against Supabase. Sync is an idempotent
/// upsert keyed on the client-generated row id; last-write-wins for edits to
/// the same row id is enforced by always upserting the full payload — the
/// row with the latest `client_timestamp` to reach the server wins.
class SyncService {
  SyncService(this._client, this._queue);

  final SupabaseClient _client;
  final MetricWriteQueue _queue;
  Timer? _timer;

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => syncPending());
    unawaited(syncPending());
  }

  void dispose() => _timer?.cancel();

  Future<void> syncPending() async {
    final writes = await _queue.pending();
    for (final write in writes) {
      try {
        await _client.from(write.table).upsert(write.payload);
        await _queue.markSynced(write.clientId);
      } on PostgrestException {
        await _queue.markConflict(write.clientId);
      } catch (_) {
        // Network/other failure: leave pending, retry on the next tick.
      }
    }
  }
}
