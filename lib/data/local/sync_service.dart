import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'metric_write_queue.dart';

/// Lets a screen push the offline-first queue immediately (e.g. right after
/// Quick Add) instead of waiting for [SyncService]'s own timer, without
/// depending on the concrete class -- constructing a real `SyncService`
/// needs a real `SupabaseClient`, which starts a background auth-refresh
/// timer that a widget test can't safely create (it outlives the test and
/// fails the "no pending timers" check). A trivial fake of this interface
/// has no such side effect.
abstract class MetricSyncTrigger {
  Future<void> syncPending();
}

/// Drains the [MetricWriteQueue] against Supabase. Sync is an idempotent
/// upsert keyed on the client-generated row id; last-write-wins for edits to
/// the same row id is enforced by always upserting the full payload — the
/// row with the latest `client_timestamp` to reach the server wins.
class SyncService implements MetricSyncTrigger {
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

  @override
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
