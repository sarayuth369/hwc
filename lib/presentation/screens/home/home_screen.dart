import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/wellness_summary.dart';
import '../../../domain/repositories/daily_summary_repository.dart';
import '../../widgets/wellness_score_card.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../health/health_screen.dart';
import '../quick_actions/quick_actions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WellnessSummary?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<WellnessSummary?> _loadSummary() =>
      context.read<DailySummaryRepository>().summaryFor(DateTime.now());

  void _refresh() => setState(() => _summaryFuture = _loadSummary());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<WellnessSummary?>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return WellnessScoreCard(summary: snapshot.data);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('homeQuickActionsButton'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuickActionsScreen(),
                      ),
                    ),
                    child: const Text('Quick Actions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('homeHealthButton'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HealthScreen()),
                    ),
                    child: const Text('Health'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('homeAskAiButton'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              ),
              child: const Text('Ask AI'),
            ),
          ],
        ),
      ),
    );
  }
}
