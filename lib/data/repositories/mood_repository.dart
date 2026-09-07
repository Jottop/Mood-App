import '../models/mood_entry.dart';

/// Contrato de persistencia de estados de ánimo.
///
/// La Fase 1 lo implementa con almacenamiento local (ver
/// [LocalMoodRepository]). La Fase 2 agregará una implementación
/// respaldada por Supabase. Como el resto de la app (provider, pantallas)
/// solo conoce esta interfaz, ese cambio no debería requerir modificar
/// ni un widget.
abstract class MoodRepository {
  Future<List<MoodEntry>> loadAll();
  Future<void> saveAll(List<MoodEntry> entries);
}
