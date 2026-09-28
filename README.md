# BKKNEX AI Health & Wellness Companion

Flutter client for the AI Health & Wellness Companion MVP (Phase 0 + Phase 1).
Backend: Supabase (schema/RLS) + a Cloudflare Worker AI gateway (`bkknex-worker`, owned separately).

## Architecture

- `lib/domain/` — pure Dart models and repository *interfaces*. No Flutter,
  Supabase, or PostHog imports here.
- `lib/data/` — concrete implementations of those interfaces.
  - `data/local/` — the offline-first write queue (`MetricWriteQueue`) and
    the `SyncService` that drains it against Supabase.
  - `data/supabase/` — Supabase-backed repository implementations. This is
    the only place `package:supabase_flutter` is imported outside `main.dart`.
  - `data/ai/` — calls only the documented Worker routes
    (`/api/ai/chat`, `/api/ai/insight`, `/api/ai/voice/*`). No vendor name or
    provider branching lives in this client (contract 1).
- `lib/presentation/` — screens and widgets. They depend on
  `domain/repositories/*` interfaces only; the real implementations are
  wired up in `presentation/app_providers.dart`.
- `lib/core/theme/` — `AppTheme` (shared design tokens) and `SeniorModeTheme`
  (extends it). `lib/core/accessibility/` holds the single
  `AccessibilityModeController` that decides which one is active — there is
  no separate "senior screens" set (contract 4).

## Locked technical contracts (BKK-76 v1)

1. **AI abstraction** — the client only calls `/api/ai/chat`, `/api/ai/insight`,
   `/api/ai/voice/*` on the Worker (`lib/domain/repositories/ai_repository.dart`,
   not wired into any screen yet — Phase 2).
2. **Wellness Score** — computed entirely by the `compute_wellness_score_v1`
   Postgres function. The client only renders `wellness_score`,
   `component_scores`, and `explanation`
   (`lib/data/supabase/daily_summary_repository_impl.dart`,
   `lib/presentation/widgets/wellness_score_card.dart`). No score math in Dart.
3. **Offline-first metric logging** — every metric write goes through
   `MetricWriteQueue` before any network call; `SyncService` performs an
   idempotent upsert keyed on the client-generated row id. This pass added
   the `client_timestamp`/`sync_status` columns the contract requires to
   `sleep_records`, `activity_records`, `water_records`, `weight_records`,
   and `nutrition_records` (Supabase migration `009_offline_sync_columns_v1`)
   — they did not exist before this heartbeat.
4. **Senior Mode** — one `AccessibilityMode` (`normal|senior`) driving the
   shared `AppTheme`/`SeniorModeTheme` token tree, persisted locally via
   `SharedPreferences`.

## Running

If `android/` doesn't exist yet (fresh clone) or you deleted it, regenerate it and patch it for
what this app needs (camera permission for Food Scanner/Health Report Reader, notification
permission for reminders, core library desugaring for `flutter_local_notifications`, the real
launcher icon and app label instead of `flutter create`'s defaults) — `android/` is gitignored,
so this must be re-run after every `flutter create`:

```
flutter create --platforms=android --org com.bkknex .
./scripts/patch_android_manifest.sh
./scripts/patch_android_build_gradle.sh
flutter pub get
./scripts/generate_launcher_icons.sh
```

```
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=WORKER_BASE_URL=... \
  --dart-define=POSTHOG_API_KEY=... \
  --dart-define=SENTRY_DSN=...
```

`SUPABASE_ANON_KEY` is the public anon key — access is enforced entirely by
Postgres RLS (`user_id = auth.uid()` on every table). No service-role or AI
provider key is ever read, stored, or referenced client-side.

## Tests

```
flutter test
```

Covers: onboarding → Home handoff, Home rendering the Wellness Score summary,
the Quick Actions log-then-refresh flow, and the Senior Mode confirmation +
toggle behavior. The Supabase RLS cross-user isolation test was run directly
against the database (SQL, not Flutter) — see the BKK-78 issue thread for
the query evidence.

## CI

`.github/workflows/ci.yml` runs on every push/PR to `main`: `flutter create
--platforms=android .` (adds the platform folder only — it does not touch
`pubspec.yaml` or `lib/`, so no generated Gradle/wrapper binaries are
checked into version control), `flutter pub get`, a secret-scan grep,
`flutter analyze`, `flutter test`, and `flutter build apk --debug`.

## Known limitations (Phase 0/1, this pass)

- PostHog event names in `lib/core/analytics/analytics_events.dart` are
  structurally-correct placeholders — they still need to be checked against
  the literal BKK-76 §23 allow-list (doc access was unavailable when this
  pass was written; see the issue thread).
- `user_preferences.senior_mode_enabled` (server) and
  `AccessibilityModeController` (local, `SharedPreferences`) are not yet
  two-way synced — Senior Mode works fully client-side today.
- `Health` screen lists recent entries per metric; there is no manual
  numeric-entry form yet beyond Quick Actions' fixed presets.
- This environment's shell/build tooling (Bash, Flutter SDK) was
  unavailable while writing this pass, so `flutter analyze` / `flutter test`
  / `flutter build apk --debug` have not been run locally — CI is the first
  real compile/test of this code. Expect a possible follow-up fix-up commit
  once CI results are in, most likely around the PostHog/Sentry init call
  shapes in `lib/main.dart`, which could not be checked against the
  installed package API surface.
