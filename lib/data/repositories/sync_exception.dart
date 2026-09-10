/// Error controlado del backend (Fase 2): representa una falla de red o del
/// servidor en las operaciones de Supabase. Se lanza para que la UI pueda
/// mostrar un mensaje (carga inicial) y se traga en los guardados (offline).
class SyncException implements Exception {
  final String message;

  const SyncException(this.message);

  @override
  String toString() => message;
}