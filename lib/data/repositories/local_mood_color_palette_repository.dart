import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'mood_color_palette_repository.dart';

/// Implementación local de [MoodColorPaletteRepository]: el estado completo
/// de la paleta (colores personalizados + colores base ocultos) se guarda
/// como un único JSON dentro de SharedPreferences.
class LocalMoodColorPaletteRepository implements MoodColorPaletteRepository {
  static const _storageKey = 'mood_color_palette';

  @override
  Future<MoodColorPaletteState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const MoodColorPaletteState();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return MoodColorPaletteState.fromJson(decoded);
  }

  @override
  Future<void> save(MoodColorPaletteState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}