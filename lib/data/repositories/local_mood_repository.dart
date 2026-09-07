import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mood_entry.dart';
import 'mood_repository.dart';

/// Persistencia 100% local y offline (Fase 1). Guarda todos los registros
/// como un único JSON en SharedPreferences.
///
/// Cuando llegue Supabase (Fase 2), esta clase se reemplaza por una
/// `SupabaseMoodRepository` que implemente el mismo [MoodRepository];
/// el resto de la app no cambia.
class LocalMoodRepository implements MoodRepository {
  static const _storageKey = 'mood_entries';

  @override
  Future<List<MoodEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAll(List<MoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
