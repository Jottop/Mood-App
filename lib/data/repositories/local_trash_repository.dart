import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trashed_mood.dart';

/// Persistencia local (SharedPreferences) de la papelera de emociones. Es
/// solo de este dispositivo (al restaurar se re-sincroniza el catálogo con
/// Supabase por el flujo normal de `saveAll`).
abstract class TrashRepository {
  Future<List<TrashedMood>> loadAll();
  Future<void> saveAll(List<TrashedMood> moods);
}

class LocalTrashRepository implements TrashRepository {
  static const _storageKey = 'mood_catalog_trash';

  @override
  Future<List<TrashedMood>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TrashedMood.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Datos corruptos: arrancamos con la papelera vacía.
      return const [];
    }
  }

  @override
  Future<void> saveAll(List<TrashedMood> moods) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(moods.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}