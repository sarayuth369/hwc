import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../data/local/sync_service.dart';
import '../../../domain/models/activity_record.dart';
import '../../../domain/models/sleep_record.dart';
import '../../../domain/models/water_record.dart';
import '../../../domain/models/weight_record.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../widgets/quick_entry_sheet.dart';
import '../food_scanner/food_scanner_screen.dart';
import '../health/health_screen.dart';

/// Opens the icon-led Quick Add sheet. Tapping a row opens a small entry
/// sheet for that metric (a numeric field/stepper, or hour+minute steppers
/// for Sleep) — nothing is saved until the user taps Save there. Replaces
/// the old stacked-button `QuickActionsScreen`, and (this pass) replaces an
/// earlier version of this sheet that silently logged a fixed default the
/// moment a row was tapped, which read as confusing/accidental logging.
///
/// [onChanged] fires once the sheet closes (however it closes — the X
/// button or dismissing the barrier) — callers use it to refresh whatever
/// summary/history views they show, since the metric repositories write
/// through an offline-first local queue and nothing else would otherwise
/// tell an already-built Home/Health screen that new data exists. Firing
/// unconditionally (rather than only when something was actually logged)
/// costs one extra cheap read and avoids fragile tracking of every way a
/// modal sheet can be dismissed.
Future<void> showQuickAddSheet(BuildContext context, {VoidCallback? onChanged}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => QuickAddSheet(onChanged: onChanged),
  );
  onChanged?.call();
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, this.onChanged});

  /// Also invoked directly (in addition to the outer `showQuickAddSheet`
  /// wrapper's own call) for the Food/More rows, which pop this sheet
  /// *before* pushing their destination screen — by the time that pushed
  /// screen is later popped, the wrapper's own await has long since
  /// resolved, so nothing would otherwise fire a refresh at the point data
  /// actually changed.
  final VoidCallback? onChanged;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  static const _analytics = AnalyticsService();
  String? _status;

  String? _requireUserId() {
    final userId = context.read<CurrentUserService>().currentUserId;
    if (userId == null) {
      setState(() => _status = 'Sign in to log entries.');
      return null;
    }
    return userId;
  }

  /// Metric writes go through an offline-first local queue (see
  /// `SyncService`'s doc comment) that would otherwise only reach Supabase
  /// on the next up-to-30s timer tick. Pushing it now means the write has
  /// already landed by the time this sheet closes and the caller refreshes
  /// — without this, "Logged ..." would show immediately while Home/Health
  /// kept showing stale data for up to 30 more seconds.
  Future<void> _syncNow() => context.read<MetricSyncTrigger>().syncPending();

  Future<void> _logWater() async {
    final amount = await showNumericEntrySheet(
      context,
      title: 'Water',
      icon: Icons.water_drop_outlined,
      unit: 'ml',
      initial: 250,
      min: 0,
      max: 2000,
      step: 50,
      presets: const [200, 250, 300, 500],
    );
    if (amount == null || !mounted) return;
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<WaterRepository>().logWater(
          WaterRecord(userId: userId, loggedAt: DateTime.now(), amountMl: amount.round()),
        );
    await _syncNow();
    unawaited(_analytics.capture(AnalyticsEvent.waterLogged));
    if (!mounted) return;
    setState(() => _status = 'Water · ${amount.round()} ml added');
  }

  Future<void> _openFoodScanner() async {
    final userId = _requireUserId();
    if (userId == null) return;
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
    );
    widget.onChanged?.call();
  }

  Future<void> _logWalk() async {
    final minutes = await showNumericEntrySheet(
      context,
      title: 'Walking',
      icon: Icons.directions_walk,
      unit: 'min',
      initial: 20,
      min: 0,
      max: 240,
      step: 5,
      presets: const [10, 20, 30, 60],
    );
    if (minutes == null || !mounted) return;
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<ActivityRepository>().logActivity(
          ActivityRecord(
            userId: userId,
            loggedAt: DateTime.now(),
            activeMinutes: minutes.round(),
            activityType: 'walking',
          ),
        );
    await _syncNow();
    if (!mounted) return;
    setState(() => _status = 'Walking · ${minutes.round()} min added');
  }

  Future<void> _logWeight() async {
    final weight = await showNumericEntrySheet(
      context,
      title: 'Weight',
      icon: Icons.monitor_weight_outlined,
      unit: 'kg',
      initial: 70,
      min: 20,
      max: 250,
      step: 0.5,
      decimals: 1,
    );
    if (weight == null || !mounted) return;
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<WeightRepository>().logWeight(
          WeightRecord(userId: userId, loggedAt: DateTime.now(), weightKg: weight),
        );
    await _syncNow();
    unawaited(_analytics.capture(AnalyticsEvent.weightLogged));
    if (!mounted) return;
    setState(() => _status = 'Weight · ${weight.toStringAsFixed(1)} kg added');
  }

  Future<void> _logSleep() async {
    final hours = await showSleepEntrySheet(context, initialHours: 7.5);
    if (hours == null || !mounted) return;
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<SleepRepository>().logSleep(
          SleepRecord(userId: userId, loggedAt: DateTime.now(), hoursSlept: hours),
        );
    await _syncNow();
    if (!mounted) return;
    final wholeHours = hours.floor();
    final minutes = ((hours - wholeHours) * 60).round();
    final label = minutes == 0 ? '${wholeHours}h' : '${wholeHours}h ${minutes}min';
    setState(() => _status = 'Sleep · $label added');
  }

  void _openMore() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HealthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Quick Add', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  key: const Key('quickAddCloseButton'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 4),
              Text(_status!, key: const Key('quickAddStatus')),
            ],
            const SizedBox(height: 8),
            // Senior Mode's larger touch targets/type scale can make these
            // 6 rows taller than the sheet's available height -- Flexible +
            // a scroll view lets it scroll internally instead of
            // overflowing (found via a Senior Mode widget test, not
            // assumed).
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuickAddRow(
                      icon: Icons.water_drop_outlined,
                      title: 'Water',
                      subtitle: 'Enter an amount',
                      onTap: _logWater,
                      actionKey: const Key('quickAddWaterRow'),
                    ),
                    _QuickAddRow(
                      icon: Icons.restaurant_outlined,
                      title: 'Food',
                      subtitle: 'Scan or add',
                      onTap: _openFoodScanner,
                      actionKey: const Key('quickAddFoodRow'),
                    ),
                    _QuickAddRow(
                      icon: Icons.directions_walk,
                      title: 'Walking',
                      subtitle: 'Add activity',
                      onTap: _logWalk,
                      actionKey: const Key('quickAddWalkRow'),
                    ),
                    _QuickAddRow(
                      icon: Icons.monitor_weight_outlined,
                      title: 'Weight',
                      subtitle: 'Add weight',
                      onTap: _logWeight,
                      actionKey: const Key('quickAddWeightRow'),
                    ),
                    _QuickAddRow(
                      icon: Icons.bedtime_outlined,
                      title: 'Sleep',
                      subtitle: 'Add sleep',
                      onTap: _logSleep,
                      actionKey: const Key('quickAddSleepRow'),
                    ),
                    _QuickAddRow(
                      icon: Icons.more_horiz,
                      title: 'More',
                      subtitle: 'See full history',
                      onTap: _openMore,
                      actionKey: const Key('quickAddMoreRow'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.actionKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: actionKey,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
