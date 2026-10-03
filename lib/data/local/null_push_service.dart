import '../../core/push/push_payload.dart';
import '../../domain/push/push_models.dart';
import '../../domain/push/push_ports.dart';

/// Honest "no push" implementation -- used where push cannot exist (widget
/// tests, builds without Firebase). Same pattern as `NullAdService`: it never
/// pretends a token was registered or a notification arrived.
class NullPushService implements PushService {
  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> onSignedIn() async {}

  @override
  Future<void> onSigningOut() async {}

  @override
  Future<PushPermissionStatus> permissionStatus() async => PushPermissionStatus.denied;

  @override
  Future<PushPermissionStatus> enable() async => PushPermissionStatus.denied;

  @override
  Stream<PushRoute> get routeRequests => const Stream.empty();

  @override
  PushRoute? takePendingRoute() => null;

  @override
  Stream<void> get inboxChanged => const Stream.empty();

  @override
  void dispose() {}
}
