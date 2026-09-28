# BKK-78 — Flutter Architecture & Design System Spec (Phase 0+1)

Written while `bkknex-health-app` repo creation is still blocked on BKK-77. This is the exact spec to scaffold from the moment the repo exists — no design decisions left open. Supabase schema/RLS (item 1 of BKK-78) is already applied and verified; see the "Supabase schema — implemented" section below.

## 1. Repository layout (to scaffold on `bkknex-health-app`)

```
lib/
  main.dart
  app.dart                      // MaterialApp, theme wiring, router
  core/
    theme/
      app_theme.dart            // ThemeData factory: standard + senior variants
      design_tokens.dart        // type scale, spacing, color tokens, touch target sizes
    routing/
      app_router.dart
    analytics/
      analytics_events.dart     // allow-listed event name constants (closed enum, see §6)
      analytics_service.dart    // wraps PostHog; rejects any event/property not on the allow-list
      crash_service.dart        // wraps Sentry; scrubs before capture
  domain/                        // pure Dart, zero Supabase/provider imports
    entities/
      profile.dart
      user_preferences.dart
      health_goal.dart
      sleep_record.dart
      activity_record.dart
      water_record.dart
      weight_record.dart
      nutrition_record.dart
      daily_health_summary.dart
      ai_conversation.dart
      ai_message.dart
    repositories/                // abstract interfaces only
      profile_repository.dart
      preferences_repository.dart
      health_goal_repository.dart
      sleep_repository.dart
      activity_repository.dart
      water_repository.dart
      weight_repository.dart
      nutrition_repository.dart
      daily_summary_repository.dart
      conversation_repository.dart
    wellness_score/
      wellness_score_view_model.dart   // maps daily_health_summary row -> display model; renders only, no math
    ai/
      ai_repository.dart          // interface: calls only /api/ai/chat, /api/ai/insight, /api/ai/voice/* contract (Worker B's Worker); no vendor name/branching ever appears here
  data/
    local/
      metric_write_queue.dart     // offline-first write queue: client uuid, client_timestamp, sync_status(pending|synced|conflict)
      metric_write_queue_store.dart // local persistence (sqlite/drift) for the queue, read/replayed by sync_service
      sync_service.dart           // drains queue -> idempotent Supabase upsert on client uuid; last-write-wins by client_timestamp on same row id
    supabase/
      supabase_client_provider.dart
      profile_repository_impl.dart
      preferences_repository_impl.dart
      health_goal_repository_impl.dart
      sleep_repository_impl.dart      // writes go through metric_write_queue first, never straight to Supabase
      activity_repository_impl.dart   // writes go through metric_write_queue first, never straight to Supabase
      water_repository_impl.dart      // writes go through metric_write_queue first, never straight to Supabase
      weight_repository_impl.dart     // writes go through metric_write_queue first, never straight to Supabase
      nutrition_repository_impl.dart  // writes go through metric_write_queue first, never straight to Supabase
      daily_summary_repository_impl.dart  // reads score_version/component_scores/explanation; calls compute_wellness_score_v1 RPC, never computes score client-side
      conversation_repository_impl.dart
      ai_repository_impl.dart     // only network calls to /api/ai/*, no provider SDK import
  presentation/
    onboarding/
    home/
    health/                      // metric logging/history screens
    quick_actions/
    accessibility/
      accessibility_mode_controller.dart  // AccessibilityMode { normal, senior } — single source of truth, read by SeniorModeTheme
    shared_widgets/
core/theme/ (see above) also gains:
      senior_mode_theme.dart      // SeniorModeTheme extends AppTheme — type scale, contrast, touch targets, motion, nav-depth collapsing tokens
test/
  unit/
    wellness_score_view_model_test.dart   // given a fixed daily_health_summary row, renders expected display model — no scoring math to test here, that's Postgres's job
    metric_write_queue_test.dart          // enqueue -> sync -> idempotent upsert; edit conflict -> last-write-wins by client_timestamp
  widget/
    onboarding_flow_test.dart
    home_screen_test.dart
    quick_action_log_and_refresh_test.dart   // one per metric type; asserts queue-then-sync path, not a direct write
    senior_mode_toggle_test.dart             // toggles AccessibilityMode, asserts SeniorModeTheme tokens applied app-wide
  integration/
    rls_isolation_test.dart      // hits a disposable Supabase test project/schema
.github/workflows/ci.yml         // flutter build apk --debug on push/PR
```

**Hard rule enforced by this layout**: `presentation/**` may only import from `domain/**`. Nothing under `presentation/` or `domain/` imports `package:supabase_flutter` or any AI provider SDK directly — only `data/supabase/**` does. This is what "screens must depend on repository interfaces, never directly on Supabase SDK calls" means concretely, and it's what makes the RLS/repo layer swappable and testable with fakes.

## 2. Design tokens (senior-friendly defaults from day one)

Standard mode is not "small text that seniors can enlarge" — both modes start from a higher baseline than typical mobile apps, and Senior Mode scales further.

| Token | Standard | Senior Mode |
|---|---|---|
| Base font size | 18sp | 24sp |
| Heading (H1) | 28sp / bold | 36sp / bold |
| Body line height | 1.4x | 1.5x |
| Minimum touch target | 48x48dp | 64x64dp |
| Button min height | 52dp | 72dp |
| Primary/background contrast | WCAG AA (4.5:1) | WCAG AAA (7:1) |
| Color-only status indicators | never — always icon + text label | same |
| Max nav destinations (bottom bar) | 4 (Home, Track, Chat, Profile) | same 4, larger icons/labels |
| Animation | standard Material easing | reduced-motion friendly, no auto-dismissing toasts |

Color palette: high-contrast, calm (per product brief — "calm, clean, comfortable"). Avoid saturated reds/greens as the only signal for good/bad wellness — pair with plain-language text ("GOOD", "Drink a little more water today") per the master-assignment §14 example screen.

`text_scale` in `user_preferences` (already in the applied schema, default 1.00, range 0.80–2.00) is a user-adjustable multiplier on top of the Standard/Senior base — so a Senior Mode user can scale further, and a Standard user with low vision isn't stuck at the small default.

## 3. Senior Mode as first-class state, not a bolt-on

- `user_preferences.senior_mode_enabled`, `high_contrast`, `text_scale` are already columns in the applied schema (see §7).
- **Locked contract 4 (BKK-76 plan rev2):** state is one `AccessibilityMode` enum (`normal|senior`), owned by `AccessibilityModeController` (ChangeNotifier or Riverpod/Bloc equivalent — MAN/Worker A to confirm state-management library at scaffold time, no dependency chosen yet), instantiated once at app root. `SeniorModeTheme extends AppTheme` reads the controller's mode and supplies type scale, contrast, touch targets, motion, and nav-depth collapsing tokens. Every screen consumes tokens from this shared theme tree — no parallel senior screen set, no duplicated routes.
- Enabling Senior Mode also simplifies navigation copy and adds a confirmation step before irreversible actions (delete a logged record, sign out) per master-assignment §14 ("Confirmation for important actions").
- Toggling Senior Mode fires the `senior_mode_enabled` analytics event (boolean property only — no other user state) and must be tested by `senior_mode_toggle_test.dart`: toggle on, assert type scale/contrast/touch targets changed and the toggle persisted to `user_preferences`.

## 4. Screens (Phase 1 scope)

- **Onboarding**: welcome → basic profile (name, DOB, locale prefilled from device) → pick 1 initial goal (sleep/activity/hydration/weight/nutrition, matches `health_goals.goal_type` check constraint) → Senior Mode opt-in prompt (plain-language, no jargon) → done. Writes `profiles` + `user_preferences` (already auto-created by the `handle_new_user` trigger on signup — onboarding only updates them) + one `health_goals` row.
- **Home**: Wellness Score display (see §5), today's snapshot (sleep/steps/water/weight-if-logged/nutrition), Quick Actions row, entry point to Chat (UI only for Phase 1 — wiring to Worker B's `/api/ai/chat` is out of scope here per the parent task).
- **Health**: per-metric log + history list (sleep/activity/water/weight/nutrition), each backed by its repository interface, each with loading/error/empty states.
- **Quick Actions**: one/two-tap logging for water (preset amounts, e.g. 250/500/750ml), weight (last-value-prefilled numeric entry + confirm), activity (steps entry or "log a walk" preset), sleep (last night's hours, quick quality picker). Each action: tap → confirm (Senior Mode only, per §14) → write via repository → refresh Home on return, which is exactly what `quick_action_log_and_refresh_test.dart` proves per action type.

No diagnosis, prescription, or medication-change copy anywhere, including placeholders — this is a hard constraint from BKK-75/76, re-stated here so it's visible at the point of UI copywriting, not just in the parent ticket.

## 5. Wellness Score — Postgres-function-only (locked contract 2, superseding the original plan wording)

BKK-76 plan revision 2 closes the "client-side or Postgres function" choice: **score math is Postgres-function-only.** `public.compute_wellness_score_v1(p_user_id uuid, p_summary_date date)` is implemented and applied to the live project (migrations `007_wellness_score_contract_v1`, `008_fix_compute_wellness_score_search_path`) — see §7. It reads that day's `sleep_records`/`activity_records`/`water_records`/`nutrition_records`, computes weighted component scores, and upserts `daily_health_summary` (`wellness_score`, `score_version`, `component_scores`, `explanation`). The function enforces `p_user_id = auth.uid()` itself and runs as the calling user (no `SECURITY DEFINER`), so RLS still governs every read/write it performs.

Flutter's job is rendering only: `domain/wellness_score/wellness_score_view_model.dart` maps a `daily_health_summary` row's `wellness_score`, `component_scores` (jsonb: `{sleep, activity, hydration, nutrition}`), and `explanation` (jsonb array of `{component, value, weight, contribution, note}`) into a display model. **No weights, thresholds, or score arithmetic may appear in the Flutter client** — if a future change needs different weighting, it happens in a `compute_wellness_score_v2` function with `score_version` bumped, not in Dart. `daily_summary_repository_impl.dart` calls the RPC (e.g. after a sync completes) and otherwise just reads the row.

v1 weights (documented in the function, not in Flutter): sleep 30%, activity 30%, hydration 20%, nutrition 20%, each component itself 0–100 against a simple per-metric target (8h sleep, 10,000 steps, 2000ml water, presence-based nutrition logging for v1). These are a first-draft placeholder pending product tuning — flagged to MAN, not a unilateral final call.

The Home screen always labels this "Wellness Score" / "lifestyle indicator," never "risk score" or anything diagnostic, per master-assignment §13.

## 6. Analytics — allow-listed events only (hard privacy gate)

`analytics_events.dart` defines a closed set of constants; `analytics_service.dart`'s `track()` method takes the enum/constant, not a free-form string, so a typo'd or ad-hoc event name is a compile error, not a runtime privacy leak. Allow-list, verbatim from master-assignment §23:

```
app_opened
onboarding_completed
quick_action_used
water_logged
weight_logged
activity_logged
ai_chat_started
ai_voice_started
food_scan_started
senior_mode_enabled
weekly_insight_viewed
paywall_viewed
subscription_started
```

Properties allowed on any event: coarse/non-identifying metadata only (e.g. `quick_action_used` may carry `action_type: "water"`, never the logged amount). No raw health values, message text, transcripts, or free-text fields ever go into event properties. `food_scan_started`/`paywall_viewed`/`subscription_started` are schema-present-but-unused in Phase 1 (those features aren't built yet) — the constant exists now so Phase 2/3 work doesn't need a new privacy review to add an event name.

Sentry (`crash_service.dart`): breadcrumbs and extra context are scrubbed before `Sentry.captureException` — a redaction step strips known health-data field names (`hours_slept`, `amount_ml`, `weight_kg`, `calories`, `content` on ai_messages, etc.) and any AI prompt/completion text, matching master-assignment §24 + BKK-76's Sentry sign-off gate. This needs a manual trigger-and-inspect test before Phase 1 sign-off, per BKK-76 — track that as a Phase 1 CI/QA step once the repo exists, not blocked on repo access to design.

## 7. Supabase schema — implemented and verified (2026-09-26, updated same day for locked contracts)

Applied directly to the connected Supabase project (`yqnzaapmznfeqdsevpyh.supabase.co`) via 8 migrations (`001_profiles_and_preferences` … `008_fix_compute_wellness_score_search_path`). All 11 tables from the parent task exist: `profiles`, `user_preferences`, `health_goals`, `sleep_records`, `activity_records`, `water_records`, `weight_records`, `nutrition_records`, `daily_health_summary`, `ai_conversations`, `ai_messages`.

- `daily_health_summary` additionally carries `score_version int`, `component_scores jsonb`, `explanation jsonb` (migration `007`), populated only by `compute_wellness_score_v1` (migration `007`, search_path hardened in `008` after the security advisor flagged it mutable — re-verified clean, 0 lints). Verified: computes correctly from seeded records, upsert is idempotent (second call does not duplicate the row), and a second user cannot invoke it against the first user's `p_user_id` (raises, caught, verified via a DO-block test with cleanup — no residual test rows).

- RLS is enabled on every table; policy is `user_id = auth.uid()` for select/insert/update/delete on every table (`profiles`/`user_preferences` key on `user_id` directly as PK; the rest have a `user_id` FK column with the same policy shape).
- No public tables, no service-role key involved — all migrations ran through the Supabase connector with project-scoped access, nothing client-side.
- `handle_new_user()` trigger on `auth.users` auto-provisions a `profiles` + `user_preferences` row on signup (`SECURITY DEFINER`, `EXECUTE` revoked from `anon`/`authenticated`/`public` after the security advisor flagged it as directly RPC-callable — advisor is clean now, re-verified).
- `set_updated_at()` trigger keeps `updated_at` fresh on `profiles`, `user_preferences`, `health_goals`, `daily_health_summary`, `ai_conversations` (same lockdown applied).
- **RLS cross-user isolation test — run and passed** (evidence in the BKK-78 comment thread): created two throwaway `auth.users` rows (A, B), one `water_records` row each, then executed as user A via `set_config('request.jwt.claim.sub', ...)` + `set local role authenticated`:
  - `select` → sees exactly 1 row, never B's.
  - `update` targeting B's row → 0 rows affected.
  - `delete` targeting B's row → 0 rows affected.
  - `insert` forging B's `user_id` → raises `insufficient_privilege`, caught and logged.
  - Post-test verification: exactly 2 rows remained (A's 250ml, B's untouched 500ml, no forged row) before cleanup.
  - Test rows deleted via `auth.users` cascade; `water_records` back to 0 rows; security advisor re-run clean (no lints).

Flutter repositories in `data/supabase/**` (§1) map 1:1 onto these tables/policies — no further schema decisions needed to start implementation.

## 8. CI

`.github/workflows/ci.yml`: on `push`/`pull_request`, `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --debug`. Add a secret-scan step (`gitleaks` or equivalent) since "no AI provider key or Supabase service-role key in the Flutter source tree or build config" is an acceptance criterion — cheaper to catch in CI than in manual review every time.

## 10. Locked Technical Contracts (v1) — compliance notes (added 2026-09-26)

Board comment on BKK-78 (2026-09-26) locked five technical contracts in BKK-76 plan rev2. Status against each, for the parts of scope reachable without the app repo:

- **Contract 1 (AI provider abstraction):** already satisfied by scope (chat UI wiring beyond the documented `/api/ai/*` contract is out of scope for this task) — now made explicit in §1 (`ai_repository.dart` interface) so it isn't accidentally violated at scaffold time.
- **Contract 2 (Wellness Score, Postgres-function-only):** implemented — see §5 and §7. This is a genuine change from the original plan wording (which allowed client-side compute); the client-side `wellness_score_calculator.dart` referenced in earlier revisions of this doc is replaced with a render-only view model.
- **Contract 3 (offline-first metric logging):** not yet built (blocked on repo per §9) but now designed into §1's `data/local/` layer (`metric_write_queue.dart`, `sync_service.dart`) so implementation starts against this contract from the first commit rather than needing rework.
- **Contract 4 (Senior Mode as one `AccessibilityMode`):** renamed/re-specified in §1 and §3 (`AccessibilityModeController`, `SeniorModeTheme extends AppTheme`) — this was already the intended direction, now made explicit in naming so there's no drift toward a parallel senior screen set.
- **Contract 5:** not named in the board comment text available to this task; if there's a fifth contract beyond the four listed, flagging to MAN to confirm scope before assuming silence means "not applicable to Flutter/Supabase."

No conflict with previously pushed code — confirmed no code exists in `bkknex-health-app` yet (still not created, checked again this heartbeat), so this is a spec correction, not a rework.

**Open question for MAN:** `daily_health_summary` already had `sleep_score`/`activity_score`/`hydration_score`/`nutrition_score` as flat int columns before this contract lock. `compute_wellness_score_v1` still populates them (for backward-compat / cheap column-level queries) in addition to the new `component_scores` jsonb, which now duplicates the same data in two shapes. Keeping both is harmless but redundant — flagging in case the board wants the flat columns dropped in a follow-up migration once Worker B/other consumers (if any) are confirmed not to depend on them.

## 9. What's blocked vs. what isn't

Blocked on BKK-77 (repo creation): scaffolding this structure into `bkknex-health-app`, all screens/widgets/tests, CI config file, the release APK build.

Not blocked, and already done: Supabase schema, RLS policies, RLS isolation test, `compute_wellness_score_v1` (locked contract 2), this spec (updated for all four locked contracts). Nothing else in Phase 0+1 scope can proceed without a repo to put code in — Flutter project scaffolding is a prerequisite for every remaining item (screens, tests, CI, secret scan of the source tree).

