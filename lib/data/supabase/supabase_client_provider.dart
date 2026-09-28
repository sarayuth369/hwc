import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';

/// Initializes the Supabase client from `--dart-define` values only. No
/// service-role key ever ships in the client — the anon key plus RLS is the
/// entire client-side access model.
Future<void> initSupabase() async {
  if (!Env.hasSupabaseConfig) return;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    // PKCE lets the SDK's own deep-link listener automatically complete a
    // sign-up/reset confirmation redirect (a `?code=...` link) once it's
    // opened via the native intent filter — see Env.authRedirectUrl.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
