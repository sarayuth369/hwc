import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ai/health_context.dart';
import '../../domain/models/ai_chat_failure.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/repositories/profile_repository.dart';

/// Calls the Worker's already-deployed `/api/ai/insight` route — the
/// `AiRepository.insight()` method existed before this pass but nothing in
/// the app ever called it. Same safety architecture as AI Talk: the client
/// only ever relays what the Worker returns.
class AiInsightCard extends StatefulWidget {
  const AiInsightCard({super.key});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  late Future<String?> _insightFuture;

  @override
  void initState() {
    super.initState();
    _insightFuture = _loadInsight();
  }

  Future<String?> _loadInsight() async {
    final profileRepository = context.read<ProfileRepository>();
    final aiRepository = context.read<AiRepository>();
    try {
      final healthContext = await buildHealthContext(profileRepository);
      final response = await aiRepository.insight({
        'healthContext': healthContext,
      });
      return response['insight'] as String?;
    } on AiChatFailure {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String?>(
      future: _insightFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Getting your insight...')),
                ],
              ),
            ),
          );
        }
        final insight = snapshot.data;
        if (insight == null || insight.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Insight",
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(insight, key: const Key('aiInsightText')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
