import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Denylist-based scrubbing applied to every event before it leaves the
/// device. Health values, message text, and transcripts must never reach
/// Sentry — this is a hard privacy gate.
const _sensitiveKeys = {
  'value',
  'message',
  'text',
  'transcript',
  'notes',
  'description',
  'calories',
  'weight_kg',
  'hours_slept',
  'amount_ml',
};

FutureOr<SentryEvent?> scrubBeforeSend(SentryEvent event, Hint hint) {
  if (event.extra != null) {
    event.extra = {
      for (final entry in event.extra!.entries)
        if (!_sensitiveKeys.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
    };
  }
  for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    if (breadcrumb.data == null) continue;
    breadcrumb.data = {
      for (final entry in breadcrumb.data!.entries)
        if (!_sensitiveKeys.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
    };
  }
  return event;
}
