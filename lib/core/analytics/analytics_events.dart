/// Allow-listed PostHog event names, verbatim from the master assignment
/// §23 (BKK-75 doc `ai-health-aicompany-mac-master-assignment-1`). Compile-
/// time constants only — call sites reference [AnalyticsEvent] values, so a
/// stray/free-form event name is a compile error, not a silent privacy
/// leak. Only names this app actually fires are declared here; add new
/// values from the §23 list (never invent new ones) as new call sites are
/// wired.
enum AnalyticsEvent {
  onboardingCompleted('onboarding_completed'),
  waterLogged('water_logged'),
  weightLogged('weight_logged');

  const AnalyticsEvent(this.eventName);

  final String eventName;
}
