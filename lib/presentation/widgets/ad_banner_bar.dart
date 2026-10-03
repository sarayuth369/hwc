import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/ads/ad_service.dart';
import '../../domain/repositories/subscription_repository.dart';

enum AdBannerPosition { top, bottom }

/// A banner ad placement that respects Premium (no ad at all once a real
/// entitlement exists) and never reserves visible space for an ad that
/// hasn't loaded — `AdService.bannerAdWidget()` returning null renders
/// nothing, not an empty gray box. Rebuilds automatically once a banner
/// that was still loading on first build finishes (via `AdService` being
/// a `ChangeNotifier`), so a slow-loading ad isn't permanently missed.
class AdBannerBar extends StatefulWidget {
  const AdBannerBar({super.key, this.position = AdBannerPosition.bottom});

  /// Which safe-area edge this bar reserves — a bottom bar (the common
  /// placement, above the bottom nav) only insets for the system nav bar;
  /// a top bar only insets for the status bar.
  final AdBannerPosition position;

  @override
  State<AdBannerBar> createState() => _AdBannerBarState();
}

class _AdBannerBarState extends State<AdBannerBar> {
  late Future<SubscriptionTier> _tierFuture;

  @override
  void initState() {
    super.initState();
    _tierFuture = context.read<SubscriptionRepository>().currentTier();
  }

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdService>();
    final widthDp = MediaQuery.sizeOf(context).width.truncate();
    return FutureBuilder<SubscriptionTier>(
      future: _tierFuture,
      builder: (context, snapshot) {
        final isPremium = snapshot.data == SubscriptionTier.premium;
        if (isPremium) return const SizedBox.shrink();
        // Premium users never trigger an ad request. For everyone else,
        // ask for a banner sized to this exact screen width (idempotent --
        // a no-op once one is loaded/loading, or ads aren't allowed). Done
        // after the frame so it never mutates state mid-build.
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) adService.prepareBanner(widthDp);
          });
        }
        final ad = adService.bannerAdWidget();
        // AnimatedSize: the bar grows in smoothly once the ad loads instead
        // of snapping the content above it upward; while there is no ad it
        // is exactly zero-height (no placeholder gap).
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: ad == null
              ? const SizedBox(width: double.infinity)
              : SafeArea(
                  // SafeArea on only the edge this bar actually touches --
                  // a top bar never needs the bottom system-nav inset and
                  // vice versa.
                  top: widget.position == AdBannerPosition.top,
                  bottom: widget.position == AdBannerPosition.bottom,
                  child: Container(
                    alignment: Alignment.center,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: ad,
                  ),
                ),
        );
      },
    );
  }
}
