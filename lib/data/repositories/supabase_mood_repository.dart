import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/network_timeout.dart';
import '../models/mood_entry.dart';
import 'mood_repository.dart';
import 'sync_exception.dart';

/// Persistencia de estados de ánimo en Supabase (Fase 2, online).
///
/// La tabla `mood_entries` es por usuario (RLS): solo el dueño lee y
/// edita sus filas; los amigos solo leen. La estrategia es de reemplazo
/// TOTAL (igual que la implementación local con SharedPreferences):
/// [saveAll] hace un upsert de todo el estado en memoria y borra las
/// filas que ya no existen.
///
/// - Si [loadAll] falla, se lanza [SyncException]: la app no debe arrancar
///   con datos vacíos porque un guardado posterior borraría el servidor.
/// - [saveAll] NUNCA propaga errores: si hay un fallo de red, el cambio
///   queda retenido en memoria y el próximo guardado (nueva mutación o
///   flush al pausar la app) reintenta con el set completo. Así la app no
///   se cae estando offline.
class SupabaseMoodRepository implements MoodRepository {
  static const table = 'mood_entries';
  static const _columns = 'id, mood_id, timestamp, logged_at';

  SupabaseClient get _client => Supabase.instance.client;

  /// Último conjunto de ids que este dispositivo conoce (último loadAll o
  /// saveAll exitoso). Permite borrar por DIFF: solo se eliminan filas que
  /// este cliente sabe que existían y ya no están en memoria. Si otro
  /// dispositivo agregó filas (o este arrancó offline), no se tocan: el
  /// viejo `delete ... not in (ids)` borraba también lo que el dispositivo
  /// jamás había visto.
  final Set<String> _knownIds = {};

  String _requireUserId() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const SyncException('Sesión no iniciada.');
    }
    return uid;
  }

  @override
  Future<List<MoodEntry>> loadAll() async {
    final uid = _requireUserId();
    try {
      final rows = await withSupabaseTimeout(
        () => _client
            .from(table)
            .select(_columns)
            .eq('user_id', uid)
            .order('timestamp'),
      );
      final entries = rows.map(_fromTable).toList();
      _knownIds
        ..clear()
        ..addAll([for (final e in entries) e.id]);
      return entries;
    } catch (_) {
      throw const SyncException(
        'No se pudieron cargar tus registros. Revisa la conexión y vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<void> saveAll(List<MoodEntry> entries) async {
    final uid = _requireUserId();
    try {
      final payload = [for (final e in entries) _toTable(e, uid)];
      if (payload.isNotEmpty) {
        await _client.from(table).upsert(payload, onConflict: 'id');
      }

      // Borrado por DIFF: solo las filas que este cliente conoce y que ya no
      // están en memoria (eliminadas localmente). Un delete `not in (ids)`
      // con todos los ids actuales borraba también filas creadas por OTRO
      // dispositivo que este nunca descargó (o al arrancar offline).
      final currentIds = {for (final e in entries) e.id};
      final removedIds = _knownIds.difference(currentIds);
      if (removedIds.isNotEmpty) {
        for (final batch in _chunks(removedIds.toList(), 500)) {
          await _client
              .from(table)
              .delete()
              .eq('user_id', uid)
              .inFilter('id', batch);
        }
      }
      _knownIds
        ..clear()
        ..addAll(currentIds);
    } catch (_) {
      // Offline: se reintenta en el próximo schedule/flush con el set
      // completo en memoria.
    }
  }

  /// Divide una lista de ids en tandas de tamaño [size] para no construir
  /// listas `in (...)` excesivamente largas en PostgREST.
  static List<List<String>> _chunks(List<String> ids, int size) {
    final out = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      out.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return out;
  }

  Map<String, dynamic> _toTable(MoodEntry e, String uid) => {
        'id': e.id,
        'user_id': uid,
        'mood_id': e.moodId,
        'timestamp': e.timestamp.toUtc().toIso8601String(),
        'logged_at': e.loggedAt.toUtc().toIso8601String(),
      };

  MoodEntry _fromTable(Map<String, dynamic> row) => MoodEntry(
        id: row['id'] as String,
        moodId: row['mood_id'] as String,
        // El servidor guarda UTC; la app trabaja con horario local.
        timestamp: DateTime.parse(row['timestamp'] as String).toLocal(),
        loggedAt: DateTime.parse(row['logged_at'] as String).toLocal(),
      );
}