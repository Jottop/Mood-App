import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/network_timeout.dart';
import '../models/mood_type.dart';
import 'mood_catalog_repository.dart';
import 'sync_exception.dart';

/// Persistencia del catálogo de estados de ánimo en Supabase (Fase 2).
///
/// Misma estrategia de reemplazo total que [SupabaseMoodRepository]: la
/// tabla `mood_catalog` es por usuario (RLS, dueño escribe, amigos leen),
/// `saveAll` hace upsert de todo y borra lo que ya no exista (2 consultas).
/// El catálogo inicial se siembra en el trigger `handle_new_user` del
/// servidor, una sola vez por cada usuario nuevo. Los errores de red en el
/// guardado se tragan (se reintenta con el set completo); si la carga falla
/// se lanza [SyncException] para no arrancar con un catálogo vacío que
/// después se guardaría encima del bueno en el servidor.
class SupabaseMoodCatalogRepository implements MoodCatalogRepository {
  static const table = 'mood_catalog';

  SupabaseClient get _client => Supabase.instance.client;

  /// Último conjunto de ids que este dispositivo conoce (ver
  /// `SupabaseMoodRepository._knownIds`): el borrado va por DIFF para no
  /// eliminar filas que otro dispositivo creó y este jamás descargó.
  final Set<String> _knownIds = {};

  String _requireUserId() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const SyncException('Sesión no iniciada.');
    }
    return uid;
  }

  @override
  Future<List<MoodType>> loadAll() async {
    final uid = _requireUserId();
    try {
      final rows = await withSupabaseTimeout(
        () => _client
            .from(table)
            .select()
            .eq('user_id', uid)
            .order('sort_order'),
      );
      final moods = rows.map(_fromTable).toList();
      _knownIds
        ..clear()
        ..addAll([for (final m in moods) m.id]);
      return moods;
    } on SyncException {
      rethrow;
    } catch (_) {
      throw const SyncException(
        'No se pudo cargar tu catálogo de estados. Revisa la conexión y vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<void> saveAll(List<MoodType> moods) async {
    final uid = _requireUserId();
    try {
      final payload = [for (var i = 0; i < moods.length; i++) _toTable(moods[i], uid, i)];
      if (payload.isNotEmpty) {
        await _client.from(table).upsert(payload, onConflict: 'id');
      }

      // El orden del usuario (drag & drop del gestor) se refleja en
      // `sort_order`; los estados eliminados se borran por DIFF de ids (solo
      // los que este dispositivo conoce y ya no están en memoria).
      final currentIds = {for (final m in moods) m.id};
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
      // Offline: se reintenta en el próximo guardado con el set completo.
    }
  }

  static List<List<String>> _chunks(List<String> ids, int size) {
    final out = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      out.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return out;
  }

  Map<String, dynamic> _toTable(MoodType m, String uid, int sortOrder) => {
        'id': m.id,
        'user_id': uid,
        'label': m.label,
        'emoji': m.emoji,
        'color': m.color.toARGB32(),
        'is_special': m.isSpecial,
        'sort_order': sortOrder,
      };

  MoodType _fromTable(Map<String, dynamic> row) => MoodType(
        id: row['id'] as String,
        label: row['label'] as String,
        emoji: row['emoji'] as String,
        color: Color(row['color'] as int),
        isSpecial: row['is_special'] as bool? ?? false,
      );
}