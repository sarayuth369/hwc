import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../domain/models/activity_record.dart';
import '../../../domain/models/sleep_record.dart';
import '../../../domain/models/water_record.dart';
import '../../../domain/models/weight_record.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../widgets/confirmation_dialog.dart';
import '../food_scanner/food_scanner_screen.dart';
import '../health/health_screen.dart';

/// Opens the icon-led Quick Add sheet (one row per metric type, each logs a
/// sensible default with a single tap — matching the product-vision board's
/// Quick Add mockup). Replaces the old stacked-button `QuickActionsScreen`.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

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

  Future<void> _logWater() async {
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<WaterRepository>().logWater(
          WaterRecord(userId: userId, loggedAt: DateTime.now(), amountMl: 250),
        );
    unawaited(_analytics.capture(AnalyticsEvent.waterLogged));
    if (!mounted) return;
    setState(() => _status = 'Logged 250ml of water.');
  }

  void _openFoodScanner() {
    final userId = _requireUserId();
    if (userId == null) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
    );
  }

  Future<void> _logWalk() async {
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<ActivityRepository>().logActivity(
          ActivityRecord(
            userId: userId,
            loggedAt: DateTime.now(),
            activeMinutes: 20,
            activityType: 'walking',
          ),
        );
    if (!mounted) return;
    setState(() => _status = 'Logged a 20-minute walk.');
  }

  Future<void> _logWeight() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: "Log today's weight?",
      message: 'This updates your weight history.',
    );
    if (!confirmed || !mounted) return;
    final userId = _requireUserId();
    if (userId == null) return;
    // Phase 0/1 placeholder value; a numeric picker lands with the full
    // metric-entry UI.
    await context.read<WeightRepository>().logWeight(
          WeightRecord(userId: userId, loggedAt: DateTime.now(), weightKg: 70),
        );
    unawaited(_analytics.capture(AnalyticsEvent.weightLogged));
    if (!mounted) return;
    setState(() => _status = "Logged today's weight.");
  }

  Future<void> _logSleep() async {
    final userId = _requireUserId();
    if (userId == null) return;
    await context.read<SleepRepository>().logSleep(
          SleepRecord(userId: userId, loggedAt: DateTime.now(), hoursSlept: 7.5),
        );
    if (!mounted) return;
    setState(() => _status = 'Logged 7.5 hours of sleep.');
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
            _QuickAddRow(
              icon: Icons.water_drop_outlined,
              title: 'Water',
              subtitle: '+250 ml',
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
