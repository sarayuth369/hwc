/// Plain-language wrapper around Supabase Auth errors so screens never show
/// raw SDK exception text.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
