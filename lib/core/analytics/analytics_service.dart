import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'analytics_events.dart';

/// Thin wrapper so every call site goes through the allow-listed
/// [AnalyticsEvent] enum. Properties must never contain raw health values,
/// message text, or transcripts — this is a hard privacy gate, not a style
/// preference, so only pass small categorical properties here.
///
/// Telemetry must never block or crash a core logging flow — capture is
/// fire-and-forget from the caller's perspective (do not await it before a
/// UI state transition) and swallows its own failures internally.
class AnalyticsService {
  const AnalyticsService();

  Future<void> capture(
    AnalyticsEvent event, {
    Map<String, Object>? properties,
  }) async {
    try {
      await Posthog().capture(
        eventName: event.eventName,
        properties: properties,
      );
    } catch (error, stack) {
      debugPrint(
          'AnalyticsService.capture failed for ${event.eventName}: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
}
