/// Thin seam over Supabase Auth. No screen ever imports `supabase_flutter`
/// directly — only `data/supabase/auth_repository_impl.dart` does.
abstract class AuthRepository {
  /// Emits the current signed-in state, then on every change.
  Stream<bool> get authStateChanges;

  bool get isSignedIn;

  Future<void> signUp({required String email, required String password});

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
