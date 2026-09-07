import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../mood_catalog.dart';
import '../models/mood_type.dart';
import 'mood_catalog_repository.dart';

class LocalMoodCatalogRepository implements MoodCatalogRepository {
  static const _storageKey = 'mood_catalog';

  @override
  Future<List<MoodType>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      // Primera vez que se abre la app: sembramos con los valores
      // por defecto y los guardamos ya como el catálogo real del usuario.
      await saveAll(MoodCatalog.defaults);
      return MoodCatalog.defaults;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    final moods = decoded
        .map((e) => MoodType.fromJson(e as Map<String, dynamic>))
        .toList();
    return _refreshDefaultColors(prefs, moods);
  }

  /// Actualiza el color de los estados por defecto a la paleta vigente
  /// (p. ej. tras saturar los colores), sin tocar estados creados por el
  /// usuario. Idempotente: solo re-escribe si algún color cambió.
  Future<List<MoodType>> _refreshDefaultColors(
    SharedPreferences prefs,
    List<MoodType> moods,
  ) async {
    final defaultColors = {
      for (final m in MoodCatalog.defaults) m.id: m.color,
    };
    var changed = false;
    final updated = moods.map((m) {
      final newColor = defaultColors[m.id];
      if (newColor == null || m.color.toARGB32() == newColor.toARGB32()) {
        return m;
      }
      changed = true;
      return m.copyWith(color: newColor);
    }).toList();
    if (changed) {
      final raw = jsonEncode(updated.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    }
    return updated;
  }

  @override
  Future<void> saveAll(List<MoodType> moods) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(moods.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
