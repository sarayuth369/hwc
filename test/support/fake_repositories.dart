import 'dart:async';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/data/local/chat_history_store.dart';
import 'package:bkknex_health_app/data/local/free_tier_subscription_repository.dart';
import 'package:bkknex_health_app/data/local/notification_service.dart';
import 'package:bkknex_health_app/data/local/null_ad_service.dart';
import 'package:bkknex_health_app/data/local/null_family_repository.dart';
import 'package:bkknex_health_app/data/local/sync_service.dart';
import 'package:bkknex_health_app/domain/ads/ad_service.dart';
import 'package:bkknex_health_app/domain/billing/billing_product.dart';
import 'package:bkknex_health_app/domain/billing/billing_service.dart';
import 'package:bkknex_health_app/domain/billing/entitlement_verifier.dart';
import 'package:bkknex_health_app/domain/billing/premium_controller.dart';
import 'package:bkknex_health_app/domain/models/activity_record.dart';
import 'package:bkknex_health_app/domain/models/ai_chat_failure.dart';
import 'package:bkknex_health_app/domain/models/nutrition_record.dart';
import 'package:bkknex_health_app/domain/models/sleep_record.dart';
import 'package:bkknex_health_app/domain/models/user_preferences.dart';
import 'package:bkknex_health_app/domain/models/user_profile.dart';
import 'package:bkknex_health_app/domain/models/water_record.dart';
import 'package:bkknex_health_app/domain/models/weight_record.dart';
import 'package:bkknex_health_app/domain/models/wellness_summary.dart';
import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/domain/repositories/auth_repository.dart';
import 'package:bkknex_health_app/domain/repositories/current_user_service.dart';
import 'package:bkknex_health_app/domain/repositories/daily_summary_repository.dart';
import 'package:bkknex_health_app/domain/repositories/family_repository.dart';
import 'package:bkknex_health_app/domain/models/notification_item.dart';
import 'package:bkknex_health_app/data/local/null_push_service.dart';
import 'package:bkknex_health_app/domain/push/push_ports.dart';
import 'package:bkknex_health_app/domain/repositories/metric_repositories.dart';
import 'package:bkknex_health_app/domain/repositories/notification_repository.dart';
import 'package:bkknex_health_app/domain/repositories/profile_repository.dart';
import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<bool>.broadcast();
  bool _signedIn = true;

  /// When true, mirrors a Supabase project with email confirmation
  /// enabled: `signUp()` succeeds but leaves `isSignedIn` false until a
  /// test explicitly calls `setSignedIn(true)` (simulating the user
  /// tapping the emailed confirmation link).
  bool requiresConfirmation = false;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  void setSignedIn(bool signedIn) {
    _signedIn = signedIn;
    _controller.add(signedIn);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    if (!requiresConfirmation) setSignedIn(true);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    setSignedIn(true);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {
    setSignedIn(false);
  }
}

class FakeCurrentUserService implements CurrentUserService {
  @override
  String? currentUserId = 'test-user';

  @override
  String? accessToken = 'test-access-token';
}

class FakeAiRepository implements AiRepository {
  Map<String, dynamic>? lastChatRequest;
  Map<String, dynamic> chatResponse = {
    'reply': 'This is a test reply.',
    'conversationId': 'test-conversation',
  };
  AiChatFailure? failure;

  /// When set, `chat()` throws [failure] this many times before finally
  /// succeeding -- lets a test simulate a transient provider hiccup that
  /// clears up on retry, without needing a real flaky network.
  int chatFailuresBeforeSuccess = 0;
  int chatCallCount = 0;

  /// Optional artificial delay so widget tests can observe the loading
  /// state between a `pump()` and `pumpAndSettle()`.
  Duration delay = Duration.zero;

  @override
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody) async {
    lastChatRequest = requestBody;
    chatCallCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (chatCallCount <= chatFailuresBeforeSuccess) {
      throw failure ?? const AiProviderFailure();
    }
    if (failure != null) throw failure!;
    return chatResponse;
  }

  @override
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody) =>
      chat(requestBody);

  Map<String, dynamic>? lastImageRequest;
  Map<String, dynamic> imageResponse = {
    'description': 'A bowl of grilled chicken with rice and vegetables.',
  };

  @override
  Future<Map<String, dynamic>> analyzeImage(
    Map<String, dynamic> requestBody,
  ) async {
    lastImageRequest = requestBody;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return imageResponse;
  }

  @override
  Future<Map<String, dynamic>> transcribeVoice(
    Map<String, dynamic> requestBody,
  ) async {
    throw failure ?? const AiNotImplementedFailure();
  }

  @override
  Future<Map<String, dynamic>> synthesizeVoice(
    Map<String, dynamic> requestBody,
  ) async {
    throw failure ?? const AiNotImplementedFailure();
  }
}

class FakeProfileRepository implements ProfileRepository {
  String? displayName;
  UserPreferences? preferences;

  @override
  Future<UserProfile?> fetchProfile() async =>
      UserProfile(userId: 'test-user', displayName: displayName);

  @override
  Future<UserPreferences?> fetchPreferences() async => preferences;

  @override
  Future<void> updateDisplayName(String name) async {
    displayName = name;
  }

  @override
  Future<void> updatePreferences(UserPreferences prefs) async {
    preferences = prefs;
  }
}

class FakeDailySummaryRepository implements DailySummaryRepository {
  WellnessSummary? summary;
  List<WellnessSummary> trend = [];

  @override
  Future<WellnessSummary?> summaryFor(DateTime date) async => summary;

  @override
  Future<List<WellnessSummary>> recentSummaries({int days = 7}) async => trend;
}

class FakeSleepRepository implements SleepRepository {
  final List<SleepRecord> logged = [];

  @override
  Future<void> logSleep(SleepRecord record) async => logged.add(record);

  @override
  Future<List<SleepRecord>> recent({int days = 7}) async => logged;
}

class FakeActivityRepository implements ActivityRepository {
  final List<ActivityRecord> logged = [];

  @override
  Future<void> logActivity(ActivityRecord record) async => logged.add(record);

  @override
  Future<List<ActivityRecord>> recent({int days = 7}) async => logged;
}

class FakeWaterRepository implements WaterRepository {
  final List<WaterRecord> logged = [];

  @override
  Future<void> logWater(WaterRecord record) async => logged.add(record);

  @override
  Future<List<WaterRecord>> recent({int days = 7}) async => logged;
}

class FakeWeightRepository implements WeightRepository {
  final List<WeightRecord> logged = [];

  @override
  Future<void> logWeight(WeightRecord record) async => logged.add(record);

  @override
  Future<List<WeightRecord>> recent({int days = 7}) async => logged;
}

class FakeNutritionRepository implements NutritionRepository {
  final List<NutritionRecord> logged = [];

  @override
  Future<void> logNutrition(NutritionRecord record) async =>
      logged.add(record);

  @override
  Future<List<NutritionRecord>> recent({int days = 7}) async => logged;
}

class FakePremiumSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<SubscriptionTier> currentTier() async => SubscriptionTier.premium;
}

/// A no-op `MetricSyncTrigger` -- the Fake* metric repositories don't write
/// through the real offline-first queue at all, so there's never anything
/// for a real sync to do in a test; this just records how many times it
/// was asked to try.
class FakeSyncTrigger implements MetricSyncTrigger {
  int callCount = 0;

  /// Lets a test observe the in-flight state between a write starting and
  /// `syncPending()` resolving (e.g. to verify a row disables itself while
  /// busy), without needing a real timer-based `SyncService`.
  Duration delay = Duration.zero;

  @override
  Future<void> syncPending() async {
    callCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }
}

/// The real monthly/yearly offers, as `PlayBillingService` would return them
/// for the `hwc_premium` subscription (prices are what Play Console has
/// configured; the app itself never hard-codes them).
BillingCatalog fakePlayCatalog() => const BillingCatalog(
      status: BillingCatalogStatus.loaded,
      products: [
        BillingProduct(
          productId: HwcSubscription.productId,
          period: BillingPeriod.monthly,
          basePlanId: HwcSubscription.monthlyBasePlanId,
          formattedPrice: r'$3.99',
        ),
        BillingProduct(
          productId: HwcSubscription.productId,
          period: BillingPeriod.yearly,
          basePlanId: HwcSubscription.yearlyBasePlanId,
          formattedPrice: r'$44.99',
        ),
      ],
    );

BillingPurchase fakePurchase({
  BillingPurchaseStatus status = BillingPurchaseStatus.purchased,
  String? token = 'token-1',
  bool needsCompletion = true,
  bool alreadyOwned = false,
  String productId = HwcSubscription.productId,
}) =>
    BillingPurchase(
      productId: productId,
      status: status,
      purchaseToken: token,
      needsCompletion: needsCompletion,
      alreadyOwned: alreadyOwned,
    );

/// Controllable stand-in for Google Play Billing. Defaults to "no plans
/// available", the honest state when nothing is configured.
class FakeBillingService implements BillingService {
  FakeBillingService({BillingCatalog? catalog})
      : catalog = catalog ??
            const BillingCatalog.unavailable(BillingCatalogStatus.productNotFound);

  BillingCatalog catalog;
  PurchaseStart startResult = PurchaseStart.started;
  int loadCatalogCalls = 0;
  int restoreCalls = 0;
  final List<BillingProduct> purchaseRequests = [];
  final List<String> purchaseAccountIds = [];
  final List<BillingPurchase> completed = [];

  /// Emitted (asynchronously, like the real plugin) whenever
  /// `restorePurchases()` is called.
  List<BillingPurchase> restoreEmits = [];

  /// When set, `purchase()` waits on it -- lets a test fire two taps while
  /// the first is still in flight.
  Completer<void>? purchaseGate;

  final _controller = StreamController<BillingPurchase>.broadcast();

  void emit(BillingPurchase purchase) => _controller.add(purchase);

  @override
  Stream<BillingPurchase> get purchases => _controller.stream;

  @override
  Future<BillingCatalog> loadCatalog() async {
    loadCatalogCalls++;
    return catalog;
  }

  @override
  Future<PurchaseStart> purchase(BillingProduct product, {required String accountId}) async {
    purchaseRequests.add(product);
    purchaseAccountIds.add(accountId);
    await purchaseGate?.future;
    return startResult;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    for (final p in restoreEmits) {
      _controller.add(p);
    }
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async => completed.add(purchase);
}

/// Mutable entitlement source, like the server-written `subscriptions` row.
class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository([this.tier = SubscriptionTier.free]);

  SubscriptionTier tier;
  bool throwOnRead = false;
  int reads = 0;

  @override
  Future<SubscriptionTier> currentTier() async {
    reads++;
    if (throwOnRead) throw Exception('offline');
    return tier;
  }
}

/// Stand-in for the backend verification call. When it answers `entitled` it
/// flips [repository] the way the real server writing the `subscriptions` row
/// would, so the controller's re-read sees Premium.
class FakeEntitlementVerifier implements EntitlementVerifier {
  FakeEntitlementVerifier({this.repository});

  final FakeSubscriptionRepository? repository;
  VerificationOutcome outcome = VerificationOutcome.entitled;
  final List<String> verifiedTokens = [];
  Completer<void>? gate;

  @override
  Future<VerificationOutcome> verify({
    required String purchaseToken,
    required String productId,
  }) async {
    verifiedTokens.add(purchaseToken);
    await gate?.future;
    if (outcome == VerificationOutcome.entitled) {
      repository?.tier = SubscriptionTier.premium;
    }
    return outcome;
  }
}

/// Builds the controller the way `app_providers.dart` does, around fakes.
PremiumController buildPremiumController({
  required BillingService billing,
  required SubscriptionRepository subscriptions,
  EntitlementVerifier? verifier,
  CurrentUserService? currentUser,
}) =>
    PremiumController(
      billing: billing,
      subscriptions: subscriptions,
      verifier: verifier ?? FakeEntitlementVerifier(),
      currentUser: currentUser ?? FakeCurrentUserService(),
    );

class FakeNotificationRepository implements NotificationRepository {
  final List<NotificationItem> items = [];

  @override
  Future<List<NotificationItem>> list({int limit = 50}) async =>
      items.take(limit).toList();

  @override
  Future<int> unreadCount() async => items.where((i) => i.isUnread).length;

  @override
  Future<void> markAsRead(String id) async {
    final index = items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final old = items[index];
    items[index] = NotificationItem(
      id: old.id,
      category: old.category,
      title: old.title,
      body: old.body,
      createdAt: old.createdAt,
      deepLink: old.deepLink,
      readAt: DateTime.now(),
    );
  }

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < items.length; i++) {
      await markAsRead(items[i].id);
    }
  }
}

/// Every provider `HomeShell`/`AuthGate` need, wired to fresh fakes. Widget
/// tests that pump the real navigation shell (whose `IndexedStack` builds
/// all four tabs immediately) need this full set, not just the providers
/// for the tab under test.
List<SingleChildWidget> fullProviderSet({
  required SharedPreferences prefs,
  FakeCurrentUserService? currentUserService,
  FakeAuthRepository? authRepository,
  FakeProfileRepository? profileRepository,
  FakeAiRepository? aiRepository,
  FakeDailySummaryRepository? dailySummaryRepository,
  FakeSleepRepository? sleepRepository,
  FakeActivityRepository? activityRepository,
  FakeWaterRepository? waterRepository,
  FakeWeightRepository? weightRepository,
  FakeNutritionRepository? nutritionRepository,
  FakeNotificationRepository? notificationRepository,
  FakeBillingService? billingService,
  SubscriptionRepository? subscriptionRepository,
  PremiumController? premiumController,
  AdService? adService,
  PushService? pushService,
}) {
  final billing = billingService ?? FakeBillingService();
  final subscriptions = subscriptionRepository ?? FreeTierSubscriptionRepository();
  return [
    Provider<CurrentUserService>.value(
      value: currentUserService ?? FakeCurrentUserService(),
    ),
    Provider<AuthRepository>.value(
      value: authRepository ?? FakeAuthRepository(),
    ),
    Provider<ProfileRepository>.value(
      value: profileRepository ?? FakeProfileRepository(),
    ),
    Provider<AiRepository>.value(
      value: aiRepository ?? FakeAiRepository(),
    ),
    Provider<ChatHistoryStore>(
      create: (_) => ChatHistoryStore(prefs),
    ),
    Provider<NotificationService>(
      create: (_) => NotificationService(prefs),
    ),
    Provider<SubscriptionRepository>.value(
      value: subscriptions,
    ),
    Provider<FamilyRepository>(
      create: (_) => NullFamilyRepository(),
    ),
    Provider<DailySummaryRepository>.value(
      value: dailySummaryRepository ?? FakeDailySummaryRepository(),
    ),
    Provider<SleepRepository>.value(
      value: sleepRepository ?? FakeSleepRepository(),
    ),
    Provider<ActivityRepository>.value(
      value: activityRepository ?? FakeActivityRepository(),
    ),
    Provider<WaterRepository>.value(
      value: waterRepository ?? FakeWaterRepository(),
    ),
    Provider<WeightRepository>.value(
      value: weightRepository ?? FakeWeightRepository(),
    ),
    Provider<NutritionRepository>.value(
      value: nutritionRepository ?? FakeNutritionRepository(),
    ),
    Provider<NotificationRepository>.value(
      value: notificationRepository ?? FakeNotificationRepository(),
    ),
    Provider<BillingService>.value(
      value: billing,
    ),
    // The single Premium state. Loads its entitlement right away (as
    // HomeShell's start() does in the app) so widgets that wait for
    // `entitlementLoaded` resolve in tests.
    ChangeNotifierProvider<PremiumController>.value(
      value: premiumController ??
          (buildPremiumController(
            billing: billing,
            subscriptions: subscriptions,
            currentUser: currentUserService,
          )..refreshEntitlement()),
    ),
    ChangeNotifierProvider<AdService>.value(
      value: adService ?? NullAdService(),
    ),
    Provider<PushService>.value(
      value: pushService ?? NullPushService(),
    ),
    Provider<MetricSyncTrigger>.value(
      value: FakeSyncTrigger(),
    ),
  ];
}
