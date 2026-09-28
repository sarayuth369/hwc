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
  );
}

SupabaseClient get supabase => Supabase.instance.client;
