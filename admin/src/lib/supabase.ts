import { createClient } from "@supabase/supabase-js";

// Anon key only -- exactly like the Flutter app. Every privileged
// operation goes through the Worker's /api/admin/* routes instead, which
// hold the service-role key server-side and check profiles.is_admin
// themselves before doing anything privileged.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);
