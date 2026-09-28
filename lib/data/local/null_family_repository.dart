import '../../domain/repositories/family_repository.dart';

/// Null-object implementation — no Family Mode backend/RLS policy exists
/// yet (see `FamilyRepository` doc). Always returns no connections.
class NullFamilyRepository implements FamilyRepository {
  @override
  Future<List<Object>> connections() async => const [];
}
