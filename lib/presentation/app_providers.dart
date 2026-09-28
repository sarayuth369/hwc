import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/accessibility/accessibility_mode_controller.dart';
import '../data/ai/http_ai_repository.dart';
import '../data/local/metric_write_queue.dart';
import '../data/local/sync_service.dart';
import '../data/supabase/current_user_service_impl.dart';
import '../data/supabase/daily_summary_repository_impl.dart';
import '../data/supabase/health_goals_repository_impl.dart';
import '../data/supabase/metric_repositories_impl.dart';
import '../data/supabase/profile_repository_impl.dart';
import '../data/supabase/supabase_client_provider.dart';
import '../domain/repositories/ai_repository.dart';
import '../domain/repositories/current_user_service.dart';
import '../domain/repositories/daily_summary_repository.dart';
import '../domain/repositories/health_goals_repository.dart';
import '../domain/repositories/metric_repositories.dart';
import '../domain/repositories/profile_repository.dart';

/// Wires the concrete Supabase-backed repositories behind their domain
/// interfaces. Screens only ever depend on the interfaces imported above —
/// never on `supabase_flutter` directly.
class AppProviders extends StatelessWidget {
  const AppProviders({
    required this.prefs,
    required this.child,
    super.key,
  });

  final SharedPreferences prefs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final client = supabase;
    final queue = MetricWriteQueue(prefs);
    final syncService = SyncService(client, queue)..start();
    final currentUserService = CurrentUserServiceImpl(client);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccessibilityModeController(prefs),
        ),
        Provider<SyncService>.value(value: syncService),
        Provider<CurrentUserService>.value(value: currentUserService),
        Provider<AiRepository>(
          create: (_) => HttpAiRepository(
            currentUserService: currentUserService,
          ),
        ),
        Provider<SleepRepository>(
          create: (_) => SleepRepositoryImpl(client, queue),
        ),
        Provider<ActivityRepository>(
          create: (_) => ActivityRepositoryImpl(client, queue),
        ),
        Provider<WaterRepository>(
          create: (_) => WaterRepositoryImpl(client, queue),
        ),
        Provider<WeightRepository>(
          create: (_) => WeightRepositoryImpl(client, queue),
        ),
        Provider<NutritionRepository>(
          create: (_) => NutritionRepositoryImpl(client, queue),
        ),
        Provider<HealthGoalsRepository>(
          create: (_) => HealthGoalsRepositoryImpl(client),
        ),
        Provider<DailySummaryRepository>(
          create: (_) => DailySummaryRepositoryImpl(client),
        ),
        Provider<ProfileRepository>(
          create: (_) => ProfileRepositoryImpl(client),
        ),
      ],
      child: child,
    );
  }
}
