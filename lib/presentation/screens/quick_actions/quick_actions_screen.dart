import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../domain/models/water_record.dart';
import '../../../domain/models/weight_record.dart';
import '../../../domain/repositories/current_user_service.dart';
import '../../../domain/repositories/metric_repositories.dart';
import '../../widgets/confirmation_dialog.dart';

/// One/two-tap logging for the most common metrics. Important actions still
/// get a plain-language confirmation per the Senior Mode requirements.
class QuickActionsScreen extends StatefulWidget {
  const QuickActionsScreen({super.key});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  static const _analytics = AnalyticsService();
  String? _status;

  Future<void> _logWater(int amountMl) async {
    final userId = context.read<CurrentUserService>().currentUserId;
    if (userId == null) {
      setState(() => _status = 'Sign in to log water.');
      return;
    }
    await context.read<WaterRepository>().logWater(
          WaterRecord(
            userId: userId,
            loggedAt: DateTime.now(),
            amountMl: amountMl,
          ),
        );
    unawaited(_analytics.capture(AnalyticsEvent.waterLogged));
    if (!mounted) return;
    setState(() => _status = 'Logged ${amountMl}ml of water.');
  }

  Future<void> _logWeight() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: "Log today's weight?",
      message: 'This updates your weight history.',
    );
    if (!confirmed) return;
    final userId = context.read<CurrentUserService>().currentUserId;
    if (userId == null) {
      setState(() => _status = 'Sign in to log weight.');
      return;
    }
    // Phase 0/1 placeholder value; a numeric picker lands with the full
    // metric-entry UI.
    await context.read<WeightRepository>().logWeight(
          WeightRecord(
            userId: userId,
            loggedAt: DateTime.now(),
            weightKg: 70,
          ),
        );
    unawaited(_analytics.capture(AnalyticsEvent.weightLogged));
    if (!mounted) return;
    setState(() => _status = "Logged today's weight.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Actions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null) ...[
              Text(_status!, key: const Key('quickActionStatus')),
              const SizedBox(height: 16),
            ],
            FilledButton(
              key: const Key('logWater250Button'),
              onPressed: () => _logWater(250),
              child: const Text('Log Water · 250ml'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('logWater500Button'),
              onPressed: () => _logWater(500),
              child: const Text('Log Water · 500ml'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('logWeightButton'),
              onPressed: _logWeight,
              child: const Text('Log Weight'),
            ),
          ],
        ),
      ),
    );
  }
}
