import 'package:flutter/material.dart';

import '../services/date_service.dart';
import '../state/mood_catalog_provider.dart';
import '../state/mood_provider.dart';
import 'models/mood_entry.dart';
import 'models/mood_type.dart';

/// Vista de SOLO LECTURA sobre los datos de un usuario (el propio o un
/// amigo). Permite que el calendario, el detalle de un día y la lista de
/// registros muestren exactamente lo mismo para uno mismo que para un
/// amigo, sin conocer la fuente (providers locales vs. snapshot remoto)
/// ni poder mutarla.
abstract class MoodViewData {
  List<MoodEntry> get allEntries;

  List<MoodEntry> entriesForDateAsc(DateTime date);
  List<MoodEntry> entriesForDateDesc(DateTime date);

  /// Resuelve el estado de un registro; para ids eliminados devuelve el
  /// estado "desconocido" (igual que [MoodCatalogProvider.byId]).
  MoodType byId(String moodId);

  /// El catálogo completo del usuario (para el selector, en modo edición).
  List<MoodType> get catalogMoods;
}

/// Adaptador "en vivo" sobre los providers de la propia sesión: envuelve
/// [MoodProvider] + [MoodCatalogProvider]. Se construye fresco en cada
/// build, así la UI reacciona a cada cambio local.
class LocalMoodViewData implements MoodViewData {
  final MoodProvider provider;
  final MoodCatalogProvider catalog;

  LocalMoodViewData({required this.provider, required this.catalog});

  @override
  List<MoodEntry> get allEntries => provider.allEntries;

  @override
  List<MoodEntry> entriesForDateAsc(DateTime date) => provider.entriesForDateAsc(date);

  @override
  List<MoodEntry> entriesForDateDesc(DateTime date) => provider.entriesForDateDesc(date);

  @override
  MoodType byId(String moodId) => catalog.byId(moodId);

  @override
  List<MoodType> get catalogMoods => catalog.moods;
}

/// Snapshot inmutable de un amigo: sus registros y su catálogo, cargados
/// una única vez. Construye el índice por día (misma clave de local) y por
/// id en el constructor, así las consultas son O(1) como en el proveedor.
class FriendMoodViewData implements MoodViewData {
  FriendMoodViewData({required List<MoodEntry> entries, required List<MoodType> catalog})
      : _entries = entries,
        _catalog = catalog {
    final byDay = <int, List<MoodEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(DateService.localDayKey(e.timestamp), () => []).add(e);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    _byDay = byDay;
    _byId = {for (final m in catalog) m.id: m};
  }

  final List<MoodEntry> _entries;
  final List<MoodType> _catalog;
  late final Map<int, List<MoodEntry>> _byDay;
  late final Map<String, MoodType> _byId;

  @override
  List<MoodEntry> get allEntries => List.unmodifiable(_entries);

  @override
  List<MoodType> get catalogMoods => List.unmodifiable(_catalog);

  @override
  List<MoodEntry> entriesForDateAsc(DateTime date) =>
      _byDay[DateService.localDayKey(date)] ?? const <MoodEntry>[];

  @override
  List<MoodEntry> entriesForDateDesc(DateTime date) => entriesForDateAsc(date).reversed.toList();

  @override
  MoodType byId(String moodId) =>
      _byId[moodId] ??
      const MoodType(id: '_unknown', label: 'Eliminado', emoji: '❔', color: Color(0xFF9AA5B1));
}