import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ads/app_open_gate.dart';
import '../../../domain/ads/ad_service.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/subscription_repository.dart';
import '../../widgets/ad_banner_bar.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../health/health_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// The app's persistent bottom-nav shell (Home / Health / AI Talk /
/// Notifications / Profile), replacing the old push-only navigation from a
/// bare Home screen. Tabs are kept alive via `IndexedStack` rather than
/// re-pushed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  int _unreadCount = 0;
  // Bumped whenever Health's data might be stale -- rekeying HealthScreen
  // forces Flutter to recreate its element (HealthScreen is otherwise a
  // `const` StatelessWidget kept alive by IndexedStack, so its FutureBuilder
  // queries would only ever run once, at first tab build).
  int _healthRefreshGen = 0;
  static const _healthTabIndex = 1;
  static const _notificationsTabIndex = 3;
  // Ads only on the two screens the prompt calls out as "suitable,
  // non-sensitive" -- never on AI Talk (chat input), Notifications, or
  // Profile (account/sign-out controls).
  static const _adEligibleTabIndexes = {0, 1};

  static const _titles = ['Home', 'Health', 'AI Talk', 'Notifications', 'Profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUnreadCount();
      // `didChangeAppLifecycleState` only fires on a *transition* (e.g.
      // backgrounded -> resumed) -- it never fires for the very first,
      // cold-start build, so cold start needs its own call. It only shows
      // if an ad happens to be loaded already; it never waits for one.
      _tryShowAppOpenAd(isColdStart: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      // A resume with no preceding pause (e.g. returning from a system
      // dialog that only made the app `inactive`) is not "coming back to
      // the app" -- no ad.
      if (pausedAt != null) {
        _tryShowAppOpenAd(isColdStart: false, awayFor: DateTime.now().difference(pausedAt));
      }
    }
  }

  DateTime? _pausedAt;

  /// Asks the ad service to show an App Open ad, but only at a moment
  /// [AppOpenGate] says it is safe to interrupt the user. The service itself
  /// still enforces loaded/unexpired/cooldown; this is the "is the user mid
  /// -task" half of the decision.
  Future<void> _tryShowAppOpenAd({required bool isColdStart, Duration? awayFor}) async {
    final adService = context.read<AdService>();
    final tier = await context.read<SubscriptionRepository>().currentTier();
    if (!mounted) return;
    final allowed = AppOpenGate.allows(
      isPremium: tier == SubscriptionTier.premium,
      isShellForegroundRoute: ModalRoute.of(context)?.isCurrent ?? false,
      tabIndex: _index,
      isColdStart: isColdStart,
      awayFor: awayFor,
    );
    if (allowed) await adService.maybeShowAppOpenAd();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await context.read<NotificationRepository>().unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // The badge is cosmetic: if notifications can't be read (offline, or
      // the backend table isn't provisioned yet) show no badge instead of
      // letting an unhandled exception escape at startup.
    }
  }

  void _select(int i) {
    final leavingNotifications = _index == _notificationsTabIndex && i != _notificationsTabIndex;
    final enteringHealth = i == _healthTabIndex && _index != _healthTabIndex;
    setState(() {
      _index = i;
      if (enteringHealth) _healthRefreshGen++;
    });
    if (leavingNotifications) _refreshUnreadCount();
  }

  void _onHomeDataChanged() => setState(() => _healthRefreshGen++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      // Bottom only, not top-and-bottom at once: `AdMobAdService` loads one
      // `BannerAd` instance, and the underlying native ad view can only be
      // attached to a single `AdWidget` at a time -- two simultaneously
      // mounted banners sharing it would fight over the same native view.
      // `AdBannerPosition.top` is still a real, tested placement (see
      // `ad_banner_bar.dart`) for any screen that wants a top banner
      // *instead of* bottom, just never both on the same screen.
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  onTalkToAi: () => _select(2),
                  onDataChanged: _onHomeDataChanged,
                ),
                HealthScreen(key: ValueKey(_healthRefreshGen), embedded: true),
                const AiChatScreen(),
                const NotificationsScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
          if (_adEligibleTabIndexes.contains(_index))
            const AdBannerBar(position: AdBannerPosition.bottom),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(
            key: Key('navHome'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            key: Key('navHealth'),
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          const NavigationDestination(
            key: Key('navAiTalk'),
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI Talk',
          ),
          NavigationDestination(
            key: const Key('navNotifications'),
            icon: _BellIcon(count: _unreadCount, filled: false),
            selectedIcon: _BellIcon(count: _unreadCount, filled: true),
            label: 'Notify',
            tooltip: 'Notifications',
          ),
          const NavigationDestination(
            key: Key('navProfile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// A bell icon with an unread-count badge — visible without being
/// intrusive: a small dot with a count up to 9, "9+" beyond that, and no
/// badge at all when the inbox is empty.
class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.count, required this.filled});

  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(filled ? Icons.notifications : Icons.notifications_outlined);
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      child: icon,
    );
  }
}
