import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/ads/ad_service.dart';
import '../../domain/repositories/subscription_repository.dart';

/// A banner ad placement that respects Premium (no ad at all once a real
/// entitlement exists) and never reserves visible space for an ad that
/// hasn't loaded — `AdService.bannerAdWidget()` returning null renders
/// nothing, not an empty gray box.
class AdBannerBar extends StatefulWidget {
  const AdBannerBar({super.key});

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
    return FutureBuilder<SubscriptionTier>(
      future: _tierFuture,
      builder: (context, snapshot) {
        if (snapshot.data == SubscriptionTier.premium) return const SizedBox.shrink();
        final ad = context.read<AdService>().bannerAdWidget();
        if (ad == null) return const SizedBox.shrink();
        return Container(
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ad,
        );
      },
    );
  }
}
