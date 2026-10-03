/// Pure "is this a good moment to show an App Open ad?" policy, kept free of
/// Flutter/AdMob so every rule is unit-testable. The ad service separately
/// enforces *whether an ad is loaded, unexpired and past its cooldown*
/// (`canShowAppOpenAd`); this decides whether the **user's current situation**
/// allows interrupting them at all.
///
/// An App Open ad is a full-screen interruption, so it is only allowed when:
/// - the user isn't a Premium subscriber;
/// - the app's home shell is the foreground route -- not while a pushed
///   screen (Food Scanner, Health Report Reader, Quick Add entry, auth
///   flows, ...), a modal sheet or a dialog is open, i.e. never in the
///   middle of a workflow;
/// - the AI Talk tab isn't showing (the user may be typing or speaking);
/// - on a *resume* (not a cold start), the app was really away for at least
///   [minimumAwayTime] -- a notification-shade pull or a system permission
///   dialog also pauses/resumes the app and must not trigger an ad.
class AppOpenGate {
  const AppOpenGate._();

  static const Duration minimumAwayTime = Duration(seconds: 30);
  static const int aiTalkTabIndex = 2;

  static bool allows({
    required bool isPremium,
    required bool isShellForegroundRoute,
    required int tabIndex,
    required bool isColdStart,
    Duration? awayFor,
  }) {
    if (isPremium) return false;
    if (!isShellForegroundRoute) return false;
    if (tabIndex == aiTalkTabIndex) return false;
    if (!isColdStart && (awayFor == null || awayFor < minimumAwayTime)) return false;
    return true;
  }
}
