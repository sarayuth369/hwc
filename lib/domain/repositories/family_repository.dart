/// Future-ready seam for Family/Caregiver mode. Sharing another person's
/// health data safely needs new Supabase RLS policies (who can read what,
/// with explicit consent) — a schema/product decision, not something a
/// client-side stub should pre-empt. The only implementation today is
/// `NullFamilyRepository` (mirrors the Worker's own `NullVoiceProvider`
/// pattern) — always empty, never fake data.
abstract class FamilyRepository {
  Future<List<Object>> connections();
}
