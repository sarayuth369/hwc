import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/accessibility/accessibility_mode_controller.dart';
import '../core/config/env.dart';
import '../core/theme/app_theme_mode_controller.dart';
import '../data/ai/http_ai_repository.dart';
import '../data/ads/admob_ad_service.dart';
import '../data/billing/play_billing_service.dart';
import '../data/local/chat_history_store.dart';
import '../data/local/free_tier_subscription_repository.dart';
import '../data/local/metric_write_queue.dart';
import '../data/local/notification_service.dart';
import '../data/local/null_family_repository.dart';
import '../data/local/sync_service.dart';
import '../data/supabase/auth_repository_impl.dart';
import '../data/supabase/current_user_service_impl.dart';
import '../data/supabase/daily_summary_repository_impl.dart';
import '../data/supabase/health_goals_repository_impl.dart';
import '../data/supabase/metric_repositories_impl.dart';
import '../data/supabase/notification_repository_impl.dart';
import '../data/supabase/profile_repository_impl.dart';
import '../data/supabase/supabase_client_provider.dart';
import '../domain/ads/ad_service.dart';
import '../domain/billing/billing_service.dart';
import '../domain/repositories/ai_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/current_user_service.dart';
import '../domain/repositories/daily_summary_repository.dart';
import '../domain/repositories/family_repository.dart';
import '../domain/repositories/health_goals_repository.dart';
import '../domain/repositories/metric_repositories.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/subscription_repository.dart';

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
    if (!Env.hasSupabaseConfig) {
      return const _BackendNotConfiguredApp();
    }

    final client = supabase;
    final queue = MetricWriteQueue(prefs);
    final syncService = SyncService(client, queue)..start();
    final currentUserService = CurrentUserServiceImpl(client);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccessibilityModeController(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AppThemeModeController(prefs),
        ),
        Provider<ChatHistoryStore>(
          create: (_) => ChatHistoryStore(prefs),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(prefs),
        ),
        Provider<SubscriptionRepository>(
          create: (_) => FreeTierSubscriptionRepository(),
        ),
        Provider<FamilyRepository>(
          create: (_) => NullFamilyRepository(),
        ),
        Provider<SyncService>.value(value: syncService),
        Provider<MetricSyncTrigger>.value(value: syncService),
        Provider<CurrentUserService>.value(value: currentUserService),
        Provider<AuthRepository>(
          create: (_) => AuthRepositoryImpl(client),
        ),
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
        Provider<NotificationRepository>(
          create: (_) => NotificationRepositoryImpl(client),
        ),
        Provider<BillingService>(
          create: (_) => PlayBillingService(),
        ),
        ChangeNotifierProvider<AdService>(
          create: (_) => AdMobAdService()..initialize(),
          // Previously a no-op -- `AdMobAdService` held onto a live
          // `BannerAd`/`AppOpenAd` with nothing ever disposing them.
          // `ChangeNotifierProvider` calls `.dispose()` on the value
          // itself automatically, which now actually disposes both.
        ),
      ],
      child: child,
    );
  }
}

/// Shown instead of crashing when this build has no `SUPABASE_URL`/
/// `SUPABASE_ANON_KEY` (see `Env.hasSupabaseConfig`) — e.g. a debug build
/// made without `--dart-define` for a pure UI review. No provider, no
/// `Supabase.instance` access; nothing below this widget depends on a
/// backend being configured.
class _BackendNotConfiguredApp extends StatelessWidget {
  const _BackendNotConfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This build has no backend configured.\n'
              'Rebuild with SUPABASE_URL and SUPABASE_ANON_KEY.',
              key: Key('backendNotConfiguredMessage'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
