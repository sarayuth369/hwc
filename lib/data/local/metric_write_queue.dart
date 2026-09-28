import 'package:shared_preferences/shared_preferences.dart';
import 'queued_write.dart';
import '../../domain/models/sync_status.dart';

/// Local-first write queue backing contract 3. Every metric repository
/// writes here before attempting any Supabase call.
class MetricWriteQueue {
  MetricWriteQueue(this._prefs);

  static const _storageKey = 'metric_write_queue_v1';
  final SharedPreferences _prefs;

  Future<void> enqueue(QueuedWrite write) async {
    final all = await pending(includeSynced: true);
    final withoutSameId = all.where((w) => w.clientId != write.clientId);
    final next = [...withoutSameId, write];
    await _persist(next);
  }

  Future<List<QueuedWrite>> pending({bool includeSynced = false}) async {
    final raw = _prefs.getString(_storageKey);
    final all = QueuedWrite.decodeList(raw);
    if (includeSynced) return all;
    return all.where((w) => w.syncStatus != SyncStatus.synced).toList();
  }

  Future<void> markSynced(String clientId) async {
    final all = await pending(includeSynced: true);
    final next = all
        .map((w) => w.clientId == clientId
            ? w.copyWith(syncStatus: SyncStatus.synced)
            : w)
        .toList();
    await _persist(next);
  }

  Future<void> markConflict(String clientId) async {
    final all = await pending(includeSynced: true);
    final next = all
        .map((w) => w.clientId == clientId
            ? w.copyWith(syncStatus: SyncStatus.conflict)
            : w)
        .toList();
    await _persist(next);
  }

  Future<void> _persist(List<QueuedWrite> writes) async {
    await _prefs.setString(_storageKey, QueuedWrite.encodeList(writes));
  }
}
