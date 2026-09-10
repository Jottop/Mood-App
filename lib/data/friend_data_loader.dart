import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/emoji_pack.dart';
import '../services/network_timeout.dart';
import 'models/mood_entry.dart';
import 'models/mood_type.dart';
import 'mood_view_data.dart';

/// Trae el snapshot read-only de un amigo (registros + catálogo) que
/// alimenta su perfil y el calendario read-only. Es la misma consulta que
/// hacía `FriendProfileScreen` internamente; ahora el widget de comparación
/// también la usa para conocer la burbuja del amigo seleccionado.
Future<FriendMoodViewData> fetchFriendMoodViewData(String friendId) async {
  final client = Supabase.instance.client;

  // Ambas consultas son independientes: se lanzan en paralelo.
  // Se trae el historial completo (no solo hoy) porque el mismo snapshot
  // alimenta el calendario read-only al abrirlo.
  final entriesFuture = client
      .from('mood_entries')
      .select('id, mood_id, timestamp, logged_at')
      .eq('user_id', friendId)
      .order('timestamp');
  final catalogFuture = client
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

  return FriendMoodViewData(entries: entries, catalog: catalog);
}