import '../models/mood_type.dart';

/// Contrato de persistencia del catálogo de estados de ánimo (separado
/// del repositorio de registros). La Fase 2 podrá implementarlo con
/// Supabase igual que [MoodRepository].
abstract class MoodCatalogRepository {
  Future<List<MoodType>> loadAll();
  Future<void> saveAll(List<MoodType> moods);
}
