# AICOMPANY --- Mac CEO Master Assignment

## Project: AI Health & Wellness Companion

**From:** M --- Founder / Board\
**To:** Mac --- CEO\
**Delegation:** Mac owns this assignment and must independently direct
MAN and Claude/Workers.\
**Execution Platform:** Paperclip at `aicompany.bkknex.com`\
**Date:** 2026-09-26

------------------------------------------------------------------------

# 1. Executive Directive

Build a global mobile application called **AI Health & Wellness
Companion**.

The product is NOT an AI Doctor and NOT a diagnostic medical app.

The product vision is:

> **Simple enough for everyone. Smart enough for you.**

The core experience is an easy, calm, accessible wellness companion that
helps users understand and improve everyday health habits.

A major differentiator is **senior-friendly usability**:

-   Large, readable typography
-   High contrast
-   Large touch targets
-   Very simple navigation
-   Minimal cognitive load
-   One/two-tap common actions
-   Text and voice interaction
-   AI can explain information in simple language
-   Read-aloud / voice response
-   Senior Mode
-   Calm, clean, comfortable visual design

The application must be global-first and support localization later.

------------------------------------------------------------------------

# 2. Founder Decision Boundaries

M will personally handle:

-   Google Play Console account/setup
-   AdMob account/setup
-   App-store account verification and other personal/legal account
    actions
-   Final production publishing/approval
-   Decisions requiring M's personal identity, payment card, government
    verification, or legal acceptance

Everything else should be handled by AICOMPANY.

**Do not repeatedly ask M for decisions that can reasonably be made by
Mac, MAN, or Workers.**

Mac is responsible for turning this directive into an executable company
plan and delegating work.

------------------------------------------------------------------------

# 3. Existing AICOMPANY Organization

Use the existing organization. Do NOT create unnecessary new companies.

``` text
M
Founder / Board
    |
    v
Mac
CEO
    |
    v
MAN
Product / Engineering Manager
    |
    +-------------------+
    |                   |
Worker A             Worker B
Main Product         AI / QA
Engineer             Engineer
```

Current Worker A and Worker B should be used first.

Do not create many specialized workers until workload justifies it.

Possible later workers:

-   Flutter/UI Specialist
-   Backend Specialist
-   AI Specialist
-   QA/Security Specialist

Only add them when necessary.

------------------------------------------------------------------------

# 4. Current AICOMPANY Connector Stack

These are already connected and should be used:

-   GitHub
-   Supabase
-   Cloudflare
-   OpenAI
-   PostHog
-   Sentry

Do not add connectors merely because they are available.

### Intended responsibilities

**GitHub** - Repository - Issues - Branches - Pull requests - Code
review - Version control

**Supabase** - Authentication - Database - Storage - RLS - User/profile
data - Wellness data - Application configuration where appropriate

**Cloudflare** - Workers - API gateway - AI gateway/routing -
Deployment - Secrets - Rate limiting/caching where useful

**OpenAI** - Available as an AI provider/fallback where appropriate. -
Do not make the app dependent on OpenAI.

**PostHog** - Product analytics - Feature flags - Usage funnels -
Retention - AI feature usage - Senior Mode usage - Conversion analysis

**Sentry** - Crash/error monitoring - Flutter errors - API/Worker
errors - Performance issues

------------------------------------------------------------------------

# 5. AI Provider Strategy

The application must NOT call AI providers directly from Flutter.

Required abstraction:

``` text
Flutter
   |
   v
Cloudflare Worker
   |
   v
AI Gateway / Router
   |
   +---- Z.ai / GLM
   +---- Gemini
   +---- OpenAI
```

Provider keys must never be shipped inside the mobile application.

Use Cloudflare secrets/environment configuration.

### MVP strategy

Use the lowest-cost/free options available within current provider
limits for development and closed testing.

Do not commit to large recurring AI costs before product-market
validation.

The architecture must support switching providers without changing the
Flutter UI/business logic.

------------------------------------------------------------------------

# 6. AI Routing Principles

Do NOT send every user action to an LLM.

Use a router:

``` text
User request
    |
    v
Intent Router
    |
    +--> Database query / deterministic logic
    |
    +--> Rule engine
    |
    +--> LLM
    |
    +--> Vision
    |
    +--> Voice pipeline
```

Examples:

**"How much water did I drink today?"** - Query Supabase. - No LLM
required.

**"How was my week?"** - Build a compact health context. - Send only
required context to AI.

**"What is this food?"** - Vision pipeline.

**"Talk with me about my sleep."** - Conversation pipeline.

This is required to control cost, latency, privacy exposure, and
reliability.

------------------------------------------------------------------------

# 7. Product Concept

Working product name:

**AI Health & Wellness Companion**

A final brand name can be selected later after brand/domain/store-name
research.

The product should feel:

-   Calm
-   Friendly
-   Modern
-   Trustworthy
-   Human
-   Simple
-   Not clinical
-   Not intimidating
-   Not overloaded with charts

Design inspiration can combine the simplicity of modern consumer apps
with accessible health/wellness UX.

Do not copy another product's UI.

------------------------------------------------------------------------

# 8. Core User Experience

The user should be able to open the app and immediately understand:

> **How am I doing today?**

Proposed Home:

``` text
Good Morning 👋

        ❤️
   WELLNESS SCORE
        82
       GOOD

Sleep       7h 20m
Activity    6,240
Water       1.8 L
Nutrition   Good

Today's Insight
You slept better than yesterday.
Keep moving and stay hydrated.

[ Ask AI ]
```

Keep the first screen simple.

Avoid excessive charts and numbers.

------------------------------------------------------------------------

# 9. Primary Navigation

Target 4--5 primary destinations:

``` text
Home
Health
AI
Progress
More
```

Senior Mode may simplify this further:

``` text
Home
Health
Ask AI
More
```

Common actions must be accessible without deep navigation.

------------------------------------------------------------------------

# 10. Quick Actions

Common actions should be one or two taps:

-   Add water
-   Add weight
-   Add meal
-   Add walk/activity
-   Add sleep
-   Open camera
-   Talk to AI
-   Type to AI

Examples:

``` text
+250 ml Water
Scan Food
Add Weight
Add Activity
Add Sleep
Ask AI
```

Do not require long forms for routine actions.

------------------------------------------------------------------------

# 11. AI Conversation

AI must support BOTH:

## Text

User types:

> "I have been sleeping only 5 hours lately. What can I do?"

AI responds in short, easy-to-understand language.

## Voice

User taps microphone and speaks.

Pipeline:

``` text
User voice
   |
Speech recognition
   |
Conversation manager
   |
Health context
   |
AI
   |
Safety layer
   |
Text response
   |
Text-to-speech
   |
AI voice response
```

The conversation must maintain context within the session.

The user should be able to switch between text and voice.

Future target:

-   Natural multi-turn voice conversation
-   Low latency
-   Interruptible voice interaction

Do not over-engineer full duplex realtime voice in the first MVP unless
the selected provider supports it economically and reliably.

------------------------------------------------------------------------

# 12. AI Health Context

The AI may use user-approved context such as:

-   Sleep
-   Activity
-   Water
-   Weight
-   Nutrition
-   Wellness trends
-   User goals
-   Conversation context

Do NOT send the entire database to the AI.

Build a minimal context object for each request.

Example:

``` json
{
  "sleep_last_night_hours": 6.2,
  "sleep_7d_average_hours": 6.8,
  "steps_today": 6240,
  "water_today_ml": 1800,
  "goal": "improve_sleep"
}
```

Only send what is necessary.

------------------------------------------------------------------------

# 13. Wellness Score

Create a consumer-friendly **Wellness Score**, not a medical risk score.

Possible dimensions:

-   Sleep
-   Activity
-   Hydration
-   Nutrition
-   Recovery / routine

The score must be clearly described as a wellness/lifestyle indicator.

Do not present it as a medical diagnosis or medical risk prediction.

The AI should explain the score simply:

> "Your wellness looks good today. Sleep is strong. Hydration is the
> main area to improve."

------------------------------------------------------------------------

# 14. Senior Mode

Senior Mode is a core differentiator, not merely a font-size setting.

Requirements:

-   Larger text
-   Larger buttons
-   Strong contrast
-   Fewer choices
-   Clear icons
-   Plain language
-   Voice-first actions
-   Read-aloud
-   Confirmation for important actions
-   Reduced visual density
-   Avoid tiny controls
-   Avoid complicated gestures
-   Avoid relying only on color to communicate status

Example:

``` text
YOUR HEALTH

      82

     GOOD

You slept well.

You walked 6,240 steps.

Drink a little more water today.

[ TALK TO AI ]
```

Test the UX with an accessibility mindset.

------------------------------------------------------------------------

# 15. AI Food Scanner

Phase 2 feature, but architecture should allow it.

Flow:

``` text
Camera
  |
Image
  |
Vision AI
  |
Food identification
  |
Estimated nutrition
  |
User confirmation
  |
Save to Today
```

Never pretend image-based calorie/nutrition estimates are exact.

Show estimates and uncertainty where appropriate.

------------------------------------------------------------------------

# 16. Health Report Reader

Future feature:

User uploads a health/lab report.

AI:

-   Extracts text
-   Explains terms in simple language
-   Summarizes results
-   Helps prepare questions for a healthcare professional

It must NOT:

-   Diagnose disease
-   Prescribe treatment
-   Tell users to stop/change medication
-   Claim medical certainty

------------------------------------------------------------------------

# 17. Family / Caregiver Mode

Future feature.

With explicit user consent, allow a user to share limited wellness
information with a family member.

Privacy must be designed before implementation.

Never silently expose health data.

------------------------------------------------------------------------

# 18. Privacy & Security Requirements

Health-related data is sensitive.

Design for:

-   Supabase RLS
-   Least privilege
-   Secure authentication
-   Encrypted transport
-   Secure secrets
-   No API keys in Flutter
-   Explicit consent for data sharing
-   Clear data deletion/export strategy
-   Minimal AI context
-   Auditability where appropriate

Do not store unnecessary sensitive data.

Do not log raw health data or private conversations unnecessarily.

Sentry/PostHog events must be reviewed so sensitive health content is
not accidentally sent to analytics/error systems.

------------------------------------------------------------------------

# 19. Health AI Safety Layer

Create a reusable skill/policy used by every AI Worker.

### Allowed

-   Explain
-   Educate
-   Summarize
-   Track
-   Wellness coaching
-   Healthy habit suggestions
-   Explain user-provided reports
-   Help prepare questions for a clinician
-   Encourage professional care when appropriate

### Not allowed

-   Definitive diagnosis
-   Prescribing medication
-   Changing medication
-   Telling users to stop medication
-   Claiming certainty from limited information
-   Replacing a healthcare professional
-   Emergency medical decision-making

If a situation may be urgent, the response should direct the user toward
appropriate professional/emergency help rather than attempting to
diagnose.

The product must include appropriate disclaimers and safety UX based on
the target markets.

------------------------------------------------------------------------

# 20. Technical Architecture

Target:

``` text
                    Mobile App
                 Flutter iOS/Android
                         |
                         v
                 Cloudflare Worker
                    API Gateway
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
         Supabase     AI Router    Storage
             |           |
             |      +----+----+----+
             |      |         |    |
             |     Z.ai    Gemini OpenAI
             |
             +---- Auth
             +---- Database
             +---- RLS
             +---- Analytics events

PostHog <---- sanitized product events
Sentry  <---- sanitized errors
```

------------------------------------------------------------------------

# 21. Suggested Supabase Data Model

Do not overbuild the schema before validating the product.

Initial entities:

``` text
profiles
user_preferences
health_goals

daily_health_summary
sleep_records
activity_records
water_records
weight_records
nutrition_records

ai_conversations
ai_messages

food_scans

health_reports

notifications
subscriptions
```

All health-related user data must have appropriate RLS.

The exact schema is MAN's responsibility to finalize after reviewing the
MVP requirements.

------------------------------------------------------------------------

# 22. API Boundaries

Cloudflare Worker should expose stable application APIs such as:

``` text
/api/health/summary
/api/health/today
/api/health/log
/api/ai/chat
/api/ai/voice
/api/ai/insight
/api/ai/food-scan
/api/reports/explain
```

Exact routes may change after architecture review.

Keep provider-specific code behind the AI provider abstraction.

------------------------------------------------------------------------

# 23. Analytics

PostHog events should measure product behavior without sending sensitive
health content.

Examples:

``` text
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

Never put raw user health values into analytics event properties unless
explicitly reviewed and justified.

------------------------------------------------------------------------

# 24. Error Monitoring

Sentry:

-   Flutter crashes
-   Worker exceptions
-   API failures
-   AI provider failures
-   Voice failures
-   Vision failures
-   Performance issues

Sanitize sensitive payloads.

------------------------------------------------------------------------

# 25. Monetization

M will handle AdMob account setup.

Product architecture should support:

## Free

-   Basic dashboard
-   Basic tracking
-   Basic AI usage
-   Basic insights
-   Ads

## Premium

Target concept, pricing to be validated later:

-   Higher AI usage
-   Voice AI
-   Food Scan
-   Advanced insights
-   Weekly AI report
-   Health report reader
-   Advanced trends
-   Family features
-   No ads

Do not hard-code pricing before market validation.

RevenueCat may be considered later if useful for subscription
management.

------------------------------------------------------------------------

# 26. Development Strategy

## Phase 0 --- Product/Architecture

Deliver:

-   Product brief
-   User personas
-   UX principles
-   Screen map
-   Architecture
-   Data model
-   AI safety policy
-   Provider abstraction
-   Analytics plan
-   Security/privacy plan

## Phase 1 --- MVP

Build:

-   Onboarding
-   Home
-   Health
-   Quick Add
-   Sleep
-   Activity
-   Water
-   Weight
-   Basic nutrition
-   Wellness Score
-   Text AI conversation
-   AI insights
-   Senior Mode
-   Supabase auth/data
-   Cloudflare Worker
-   Z.ai integration
-   PostHog
-   Sentry

## Phase 2 --- AI Experience

Build:

-   Voice conversation
-   Speech-to-text
-   Text-to-speech
-   Food Scanner
-   Better AI context
-   Weekly AI review

## Phase 3 --- Advanced

Build:

-   Health report reader
-   Wearable integrations
-   Family mode
-   Subscription
-   Advanced personalization

------------------------------------------------------------------------

# 27. MVP Definition of Done

MVP is not complete until:

-   App builds successfully
-   Authentication works
-   User can create/edit wellness records
-   Home dashboard works
-   Wellness Score works
-   AI text conversation works
-   AI maintains conversation context
-   AI receives only necessary health context
-   AI safety rules are enforced
-   Senior Mode works
-   PostHog events work without leaking sensitive health data
-   Sentry works without leaking sensitive health data
-   API keys are server-side only
-   Supabase RLS is tested
-   Cloudflare Worker works
-   AI provider fallback/error handling exists
-   Offline/error states are handled
-   Unit/widget/integration tests exist for critical paths
-   No critical Sentry errors
-   Documentation exists
-   GitHub repository is clean
-   Release candidate APK/AAB can be produced

------------------------------------------------------------------------

# 28. Worker A Assignment

Worker A is the primary product engineer.

Responsibilities:

1.  Create/prepare GitHub repository.
2.  Establish Flutter project architecture.
3.  Build design system.
4.  Build onboarding.
5.  Build Home.
6.  Build Health screens.
7.  Build Quick Actions.
8.  Integrate Supabase.
9.  Implement RLS-aware data access.
10. Integrate Cloudflare Worker APIs.
11. Implement Senior Mode.
12. Implement text AI UI.
13. Implement loading/error/empty states.
14. Implement tests.
15. Produce release candidate builds.

Worker A must not put AI provider secrets in the mobile app.

------------------------------------------------------------------------

# 29. Worker B Assignment

Worker B is AI / QA / Safety engineer.

Responsibilities:

1.  Design AI provider abstraction.
2.  Implement Z.ai integration through Cloudflare.
3.  Prepare Gemini/OpenAI provider interfaces for future use.
4.  Design conversation context.
5.  Build AI health context builder.
6.  Build safety layer.
7.  Create AI system prompts.
8.  Test hallucination/safety edge cases.
9.  Prepare voice architecture.
10. Review analytics privacy.
11. Test AI failure/fallback behavior.
12. Review Worker A's implementation.
13. Maintain AI/QA documentation.

------------------------------------------------------------------------

# 30. MAN Responsibilities

MAN owns execution.

MAN must:

-   Break the project into actionable tasks.
-   Assign tasks to Worker A/B.
-   Define dependencies.
-   Review work before escalation.
-   Prevent duplicated work.
-   Keep GitHub issues updated.
-   Maintain project status.
-   Escalate only decisions requiring Mac/M.
-   Ensure every milestone has a Definition of Done.
-   Require tests before marking engineering tasks complete.

------------------------------------------------------------------------

# 31. Mac CEO Responsibilities

Mac owns the overall project.

Mac must:

-   Translate M's vision into strategy.
-   Approve architecture.
-   Resolve cross-worker conflicts.
-   Review MAN's plans.
-   Protect scope.
-   Control unnecessary infrastructure/API spending.
-   Review security/privacy decisions.
-   Ensure global readiness.
-   Decide when to move from MVP to Phase 2.
-   Present M only with decisions that actually require Founder
    approval.

Mac should use the existing AICOMPANY connectors rather than creating
unnecessary parallel systems.

------------------------------------------------------------------------

# 32. Cost Control

Priority:

1.  Use free tiers where appropriate during development.
2.  Avoid unnecessary LLM calls.
3.  Use deterministic logic for deterministic questions.
4.  Cache safe non-personalized data where appropriate.
5.  Keep AI context compact.
6.  Add rate limits.
7.  Track AI usage.
8.  Prepare provider fallback.
9.  Do not add expensive infrastructure until usage justifies it.

No local LLM installation is required on the Paperclip VPS for MVP.

Do not install Ollama or another large local model on the Paperclip VPS
unless a future architecture decision explicitly requires it.

------------------------------------------------------------------------

# 33. Paperclip/VPS Principle

The Paperclip VPS is primarily the:

> **AICOMPANY Control Plane**

Do not turn it into the application's entire production infrastructure.

Keep responsibilities separated:

``` text
Paperclip VPS
  -> AI company / agents / orchestration

Cloudflare
  -> public API / Worker / AI gateway

Supabase
  -> application data / auth / storage

GitHub
  -> source control

PostHog
  -> product analytics

Sentry
  -> reliability
```

Do not install additional databases, Redis, Ollama, or other
infrastructure unless MAN documents a concrete requirement and Mac
approves it.

------------------------------------------------------------------------

# 34. Execution Rules

1.  Inspect the existing repository/environment before creating new
    files.
2.  Reuse existing BKKNEX conventions where appropriate.
3.  Do not overwrite unrelated projects.
4.  Use Git branches/PRs for meaningful changes.
5.  Commit logical units of work.
6.  Test before declaring completion.
7.  Never claim a task is complete without evidence.
8.  Document important architectural decisions.
9.  Avoid premature complexity.
10. Keep MVP small enough to ship.
11. Prefer reversible decisions.
12. Protect user health data.
13. Protect API secrets.
14. Do not expose raw health information in logs/analytics.
15. Do not ask M for routine implementation decisions.

------------------------------------------------------------------------

# 35. First Actions for Mac

Mac should now:

### Step 1

Create/confirm the Health App project in Paperclip.

### Step 2

Assign MAN as owner.

### Step 3

Give MAN this specification as the source of truth.

### Step 4

Have MAN inspect the current AICOMPANY/GitHub environment before
implementation.

### Step 5

Have MAN produce a short execution plan with:

-   repository
-   milestones
-   task dependencies
-   Worker A tasks
-   Worker B tasks
-   expected deliverables

### Step 6

Start Phase 0.

### Step 7

Do not start massive coding until architecture and MVP screen map are
accepted internally by Mac/MAN.

### Step 8

After Phase 0, begin Phase 1 MVP.

------------------------------------------------------------------------

# 36. Reporting Format

MAN should report to Mac:

``` text
PROJECT STATUS

Phase:
Progress:

Completed:
- ...

In progress:
- ...

Blocked:
- ...

Decisions needed:
- ...

Risks:
- ...

Next:
- ...
```

Worker reports should contain evidence:

-   Commit/PR
-   Tests
-   Build result
-   Screenshots where relevant
-   Known limitations

------------------------------------------------------------------------

# 37. Final Success Definition

The product succeeds when a first-time user can:

``` text
Install
  ↓
Understand immediately
  ↓
Create a simple profile
  ↓
See today's wellness
  ↓
Log water/activity/weight/sleep easily
  ↓
Ask AI by text
  ↓
Understand the answer
  ↓
Return the next day
```

A senior user should be able to do the same without needing technical
knowledge.

The product should feel:

> **Simple. Calm. Human. Intelligent.**

------------------------------------------------------------------------

# 38. Mac's Immediate Command

Mac, take ownership of this project.

Do not wait for M to manage individual tasks.

Use MAN as the execution manager and Worker A/B as the initial delivery
team.

Inspect the existing AICOMPANY environment, repositories, connectors,
and current Worker capabilities.

Then create the execution plan and begin Phase 0.

Only escalate to M when the decision involves:

-   Founder-level product direction
-   Legal/privacy acceptance
-   Personal account/payment/identity verification
-   Production publishing
-   Significant recurring cost
-   A material change to the product vision

Everything else should be handled by Mac/MAN/Workers.

**End of Founder Assignment**
