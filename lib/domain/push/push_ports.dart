import '../../core/push/push_payload.dart';
import 'push_models.dart';

/// Thin seam over Firebase Messaging. The only implementation that touches
/// Firebase is `FirebaseFcmGateway`; everything else (and every test) talks
/// to this interface.
abstract class FcmGateway {
  /// Initializes Firebase. Throws if Firebase is unavailable or not
  /// configured (e.g. no `google-services.json` in this build) -- the caller
  /// treats that as "push disabled", never fatal.
  Future<void> initialize();

  /// Current notification permission, without prompting. (Android < 13
  /// grants implicitly.)
  Future<PushPermissionStatus> permissionStatus();

  /// Shows the system permission prompt where the OS requires one.
  Future<PushPermissionStatus> requestPermission();

  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground (the OS does not
  /// display these itself).
  Stream<PushMessage> get onForegroundMessage;

  /// The user tapped a push that was shown while the app was in the
  /// background.
  Stream<PushMessage> get onMessageOpenedApp;

  /// The push whose tap launched the app from a terminated state, if any.
  Future<PushMessage?> getInitialMessage();
}

/// Stores this device's push token against the signed-in user (Supabase RPCs
/// `register_push_token` / `deactivate_push_token`, see
/// `supabase/migrations/0005_push_tokens.sql`). Anonymous callers are
/// rejected server-side.
abstract class PushTokenRepository {
  Future<void> register({
    required String token,
    required String platform,
    required String deviceId,
    required String appVersion,
  });

  Future<void> deactivate(String token);
}

/// Displays a foreground push as a local notification (the OS handles
/// background/terminated ones itself, so this is never used for those --
/// avoiding duplicates).
abstract class LocalPushPresenter {
  Future<void> initialize();
  Future<void> show(PushMessage message, PushPayload? payload);

  /// Payload route of a local push the user tapped.
  Stream<PushPayload> get taps;
}

/// App-facing push facade: token lifecycle, foreground display and tap
/// routing. `HomeShell` / Settings / sign-out only talk to this.
abstract class PushService {
  /// False when Firebase could not initialize (unconfigured build, no Play
  /// services, ...). Everything else is a safe no-op in that case.
  bool get isAvailable;

  /// Starts Firebase + listeners. Never throws, never blocks startup.
  Future<void> initialize();

  /// Called once the user is signed in (and again on resume): registers this
  /// device's token if permission allows. Idempotent.
  Future<void> onSignedIn();

  /// Called BEFORE sign-out (the RPC needs the session): deactivates this
  /// device's token for the current user. Never throws.
  Future<void> onSigningOut();

  Future<PushPermissionStatus> permissionStatus();

  /// User-initiated enable (Settings): asks for permission and registers.
  Future<PushPermissionStatus> enable();

  /// Navigation requests from taps (warm start / foreground-notification
  /// taps). Deduplicated.
  Stream<PushRoute> get routeRequests;

  /// A route requested before anyone was listening (cold start); returns it
  /// once.
  PushRoute? takePendingRoute();

  /// Fires when the inbox may have new rows (a push arrived in foreground).
  Stream<void> get inboxChanged;

  void dispose();
}
