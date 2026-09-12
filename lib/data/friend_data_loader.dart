import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/emoji_pack.dart';
import '../services/network_timeout.dart';
import 'models/mood_entry.dart';
import 'models/mood_type.dart';
import 'mood_view_data.dart';

/// TTL de la caché en memoria: suficiente para no re-descargar al volver a
/// abrir el perfil (o solapar una carga concurrente) y lo bastante corto
/// para no mostrar datos añejos.
const _cacheTtl = Duration(seconds: 30);

final _cache = <String, _Cached>{};

class _Cached {
  final DateTime at;
  final FriendMoodViewData data;
  _Cached(this.at, this.data);
}

/// Trae el snapshot read-only de un amigo (registros + catálogo) que
/// alimenta su perfil y el calendario read-only. Es la misma consulta que
/// hacía `FriendProfileScreen` internamente; ahora el widget de comparación
/// también la usa para conocer la burbuja del amigo seleccionado.
///
/// [client] permite inyectar un cliente distinto (p. ej. uno construido en
/// una tarea de fondo sin pasar por `Supabase.instance`); por defecto usa el
/// cliente global de la app.
Future<FriendMoodViewData> fetchFriendMoodViewData(
  String friendId, {
  SupabaseClient? client,
}) async {
  if (client == null) {
    final cached = _cache[friendId];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.data;
    }
  }

  final supabaseClient = client ?? Supabase.instance.client;

  // Ambas consultas son independientes: se lanzan en paralelo.
  // Se trae el historial completo (no solo hoy) porque el mismo snapshot
  // alimenta el calendario read-only al abrirlo.
  final entriesFuture = supabaseClient
      .from('mood_entries')
      .select('id, mood_id, timestamp, logged_at')
      .eq('user_id', friendId)
      .order('timestamp');
  final catalogFuture = supabaseClient
      .from('mood_catalog')
      .select()
      .eq('user_id', friendId)
      .order('sort_order');
  final results = await withSupabaseTimeout(
      () => Future.wait([entriesFuture, catalogFuture]));
  final entriesRows = results[0];
  final catalogRows = results[1];

  final entries = entriesRows.map((row) => MoodEntry(
        id: row['id'] as String,
        moodId: row['mood_id'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String).toLocal(),
        loggedAt: DateTime.parse(row['logged_at'] as String).toLocal(),
      )).toList();
  final catalog = catalogRows.map((row) => MoodType(
            id: row['id'] as String,
            label: row['label'] as String,
            // Saneo: los emojis del amigo fuera del pack se reencuadran a uno
            // seguro para que nunca rendericen como cuadros vacíos.
            emoji: EmojiPack.sanitize(row['emoji'] as String),
            color: Color(row['color'] as int),
            isSpecial: row['is_special'] as bool? ?? false,
          )).toList();

  final view = FriendMoodViewData(entries: entries, catalog: catalog);
  if (client == null) {
    _cache[friendId] = _Cached(DateTime.now(), view);
  }
  return view;
}

/// "Fingerprint" remoto del amigo: una firma compacta y barata (1 fila de
/// registros + el catálogo, que es diminuto) que cambia cuando el amigo
/// registra/borra ánimos o edita su catálogo. Sirve para que el refresco
/// periódico del widget NO re-descargue el historial completo cuando nada
/// cambió (el historial es lo caro; el catálogo de ~28 filas es trivial).
Future<String> friendDataFingerprint(String friendId,
    {SupabaseClient? client}) async {
  final supabaseClient = client ?? Supabase.instance.client;
  final results = await withSupabaseTimeout(
    () => Future.wait([
      supabaseClient
          .from('mood_entries')
          .select('logged_at')
          .eq('user_id', friendId)
          .order('logged_at', ascending: false)
          .limit(1),
      supabaseClient
          .from('mood_catalog')
          .select('id, label, emoji, color, is_special')
          .eq('user_id', friendId)
          .order('sort_order'),
    ]),
  );
  final maxRows = results[0];
  final maxLogged =
      maxRows.isEmpty ? '' : (maxRows.first['logged_at'] as String);
  final catalogRows = results[1];
  final catalogSig = [
    for (final r in catalogRows)
      '${r['id']}|${r['label']}|${r['emoji']}|${r['color']}|${r['is_special']}'
  ].join(';');
  return '$maxLogged#$catalogSig';
}

/// Fingerprint LOCAL de un snapshot ya cargado, con el mismo formato que
/// [friendDataFingerprint]. El refresco lo compara contra el remoto: si son
/// iguales, no hay que re-descargar nada.
String friendViewFingerprint(FriendMoodViewData view) {
  var maxLogged = '';
  for (final e in view.allEntries) {
    final iso = e.loggedAt.toIso8601String();
    if (iso.compareTo(maxLogged) > 0) maxLogged = iso;
  }
  // El orden del catálogo importa (sort_order): la concatenación los lista en
  // el orden en que fueron cargados, así un reordenamiento cambia la firma.
  final catalogSig = [
    for (final m in view.catalogMoods)
      '${m.id}|${m.label}|${m.emoji}|${m.color.toARGB32()}|${m.isSpecial}'
  ].join(';');
  return '$maxLogged#$catalogSig';
}