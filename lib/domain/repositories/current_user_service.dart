abstract class CurrentUserService {
  String? get currentUserId;

  /// The signed-in user's Supabase access token, for the `Authorization:
  /// Bearer` header on Worker calls. Never a server-side secret — this is
  /// the user's own short-lived session token.
  String? get accessToken;
}
