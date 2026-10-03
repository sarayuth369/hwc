import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_info.dart';
import '../../core/push/push_payload.dart';
import '../../domain/push/push_models.dart';
import '../../domain/push/push_ports.dart';
import '../../domain/repositories/current_user_service.dart';

/// Token lifecycle + notification handling on top of FCM.
///
/// Design rules (all covered by tests with fakes -- no real Firebase):
/// - Never throws to callers and never blocks startup: every public method
///   catches, logs a masked/redacted line, and degrades to "push disabled".
/// - A token is registered only for a signed-in user and only when the OS
///   permission is granted; sign-out deactivates it (best effort) *before*
///   the session disappears.
/// - Registering the same token again in a session is skipped (duplicate
///   protection); the database also upserts by token.
/// - Foreground pushes are shown as a local notification (the OS does not
///   show them); background/terminated ones are displayed by the OS, so we
///   never create a second notification for those.
/// - Tap routing accepts only a validated [PushPayload]; malformed/unknown
///   payloads are ignored, and the same push is handled once.
class FcmPushService implements PushService {
  FcmPushService({
    required FcmGateway gateway,
    required PushTokenRepository tokenRepository,
    required LocalPushPresenter presenter,
    required CurrentUserService currentUser,
    required SharedPreferences prefs,
    String platform = 'android',
    String appVersion = AppInfo.version,
  })  : _gateway = gateway,
        _tokens = tokenRepository,
        _presenter = presenter,
        _currentUser = currentUser,
        _prefs = prefs,
        _platform = platform,
        _appVersion = appVersion;

  static const _deviceIdKey = 'push_device_id_v1';
  static const _permissionAskedKey = 'push_permission_asked_v1';
  static const _maxRememberedMessages = 50;

  final FcmGateway _gateway;
  final PushTokenRepository _tokens;
  final LocalPushPresenter _presenter;
  final CurrentUserService _currentUser;
  final SharedPreferences _prefs;
  final String _platform;
  final String _appVersion;

  final _routes = StreamController<PushRoute>.broadcast();
  final _inbox = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _handledMessageIds = <String>[];

  bool _available = false;
  Future<void>? _initFuture;
  PushRoute? _pendingRoute;
  String? _lastRegisteredToken;
  Future<void>? _registering;

  @override
  bool get isAvailable => _available;

  @override
  Stream<PushRoute> get routeRequests => _routes.stream;

  @override
  Stream<void> get inboxChanged => _inbox.stream;

  @override
  PushRoute? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  void _log(String message) => debugPrint('PushService: $message');

  // --- Startup ------------------------------------------------------------

  @override
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _gateway.initialize();
    } catch (e) {
      // No google-services.json in this build, no Play services, etc.
      _log('Firebase unavailable, push disabled ($e)');
      return;
    }
    _available = true;

    try {
      await _presenter.initialize();
    } catch (e) {
      _log('local presenter failed to initialize: $e');
    }

    _listen<String>(_gateway.onTokenRefresh, _onTokenRefreshed);
    _listen<PushMessage>(_gateway.onForegroundMessage, _onForegroundMessage);
    _listen<PushMessage>(_gateway.onMessageOpenedApp, (m) => _routeFromMessage(m));
    _listen<PushPayload>(_presenter.taps, (p) => _emitRoute(p.route));

    try {
      final initial = await _gateway.getInitialMessage();
      if (initial != null) _routeFromMessage(initial);
    } catch (e) {
      _log('could not read the launch notification: $e');
    }
  }

  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subscriptions.add(stream.listen(
      (event) {
        try {
          onData(event);
        } catch (e) {
          _log('handler failed: $e');
        }
      },
      onError: (Object e) => _log('stream error: $e'),
    ));
  }

  // --- Token lifecycle ----------------------------------------------------

  @override
  Future<PushPermissionStatus> permissionStatus() async {
    if (!_available) return PushPermissionStatus.denied;
    try {
      return await _gateway.permissionStatus();
    } catch (_) {
      return PushPermissionStatus.denied;
    }
  }

  @override
  Future<void> onSignedIn() async {
    await initialize();
    if (!_available || _currentUser.currentUserId == null) return;
    // Coalesce concurrent calls (HomeShell mount + resume).
    final inFlight = _registering;
    if (inFlight != null) return inFlight;
    final run = _registerCurrentToken().whenComplete(() => _registering = null);
    _registering = run;
    return run;
  }

  @override
  Future<PushPermissionStatus> enable() async {
    await initialize();
    if (!_available) return PushPermissionStatus.denied;
    PushPermissionStatus status;
    try {
      status = await _gateway.requestPermission();
      await _prefs.setBool(_permissionAskedKey, true);
    } catch (e) {
      _log('permission request failed: $e');
      return PushPermissionStatus.denied;
    }
    if (status == PushPermissionStatus.granted) {
      await _registerCurrentToken(force: true);
    }
    return status;
  }

  Future<void> _registerCurrentToken({bool force = false}) async {
    try {
      if (_currentUser.currentUserId == null) return;

      var status = await _gateway.permissionStatus();
      if (status != PushPermissionStatus.granted && !(_prefs.getBool(_permissionAskedKey) ?? false)) {
        // Ask once, automatically, after sign-in. Later requests only happen
        // when the user asks (Settings), so a "no" is never nagged.
        await _prefs.setBool(_permissionAskedKey, true);
        status = await _gateway.requestPermission();
      }
      if (status != PushPermissionStatus.granted) {
        _log('notification permission not granted; not registering a token');
        return;
      }

      final token = await _gateway.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token, force: force);
    } catch (e) {
      _log('token registration skipped: $e');
    }
  }

  Future<void> _registerToken(String token, {bool force = false}) async {
    if (!force && token == _lastRegisteredToken) return;
    try {
      await _tokens.register(
        token: token,
        platform: _platform,
        deviceId: _deviceId(),
        appVersion: _appVersion,
      );
      _lastRegisteredToken = token;
      _log('registered token ${maskPushToken(token)}');
    } catch (e) {
      // Backend unavailable (offline, migration not applied, ...): leave the
      // token unregistered so the next sign-in/resume tries again.
      _lastRegisteredToken = null;
      _log('could not register token ${maskPushToken(token)}: $e');
    }
  }

  Future<void> _onTokenRefreshed(String token) async {
    if (!_available || _currentUser.currentUserId == null) return;
    if ((await permissionStatus()) != PushPermissionStatus.granted) return;
    await _registerToken(token, force: true);
  }

  @override
  Future<void> onSigningOut() async {
    try {
      if (!_available) return;
      final token = _lastRegisteredToken ?? await _gateway.getToken();
      _lastRegisteredToken = null;
      if (token == null || token.isEmpty) return;
      await _tokens.deactivate(token).timeout(const Duration(seconds: 5));
      _log('deactivated token ${maskPushToken(token)}');
    } catch (e) {
      // Never block sign-out. The Worker also deactivates tokens FCM reports
      // as invalid, and the next sign-in on this device re-assigns the token.
      _log('could not deactivate token on sign-out: $e');
    }
  }

  String _deviceId() {
    var id = _prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      unawaited(_prefs.setString(_deviceIdKey, id));
    }
    return id;
  }

  // --- Messages -----------------------------------------------------------

  void _onForegroundMessage(PushMessage message) {
    if (_alreadyHandled(message, 'fg')) return;
    final payload = PushPayload.tryParse(message.data);
    unawaited(_presenter.show(message, payload).catchError((Object e) {
      _log('could not show foreground notification: $e');
    }));
    if (!_inbox.isClosed) _inbox.add(null);
  }

  /// Handles a tap that opened the app (warm or cold start).
  void _routeFromMessage(PushMessage message) {
    if (_alreadyHandled(message, 'open')) return;
    final payload = PushPayload.tryParse(message.data);
    if (payload == null) {
      _log('ignoring tap with a malformed or unknown payload');
      return;
    }
    _emitRoute(payload.route);
  }

  void _emitRoute(PushRoute route) {
    if (_routes.hasListener) {
      _routes.add(route);
    } else {
      _pendingRoute = route;
    }
  }

  /// True if this exact push was already handled for [kind] (an `open` can be
  /// reported both via `getInitialMessage` and `onMessageOpenedApp`).
  bool _alreadyHandled(PushMessage message, String kind) {
    final id = message.messageId;
    if (id == null || id.isEmpty) return false;
    final key = '$kind:$id';
    if (_handledMessageIds.contains(key)) return true;
    _handledMessageIds.add(key);
    if (_handledMessageIds.length > _maxRememberedMessages) _handledMessageIds.removeAt(0);
    return false;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _routes.close();
    _inbox.close();
  }
}
