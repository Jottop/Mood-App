import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/mood_type.dart';
import '../data/repositories/mood_catalog_repository.dart';
import 'debounced_persistence.dart';

/// Única fuente de verdad del catálogo de estados de ánimo. Permite
/// agregar, editar y eliminar estados en tiempo real (spec §1), y
/// delega la persistencia al [MoodCatalogRepository] inyectado.
///
/// Mantiene un índice [byId] para resolver los estado de los registros en
/// O(1) en vez de escanear la lista por cada tarjeta/celda. La escritura a
/// disco se difiere ([_persistence]) igual que en [MoodProvider]; [flushNow]
/// fuerza el guardado pendiente al pausar la app.
class MoodCatalogProvider extends ChangeNotifier {
  MoodCatalogProvider({required MoodCatalogRepository repository}) : _repository = repository;

  final MoodCatalogRepository _repository;
  final _uuid = const Uuid();

  List<MoodType> _moods = [];
  Map<String, MoodType> _byId = const {};
  bool _loading = true;

  late final DebouncedPersistence _persistence = DebouncedPersistence(
    () => _repository.saveAll(_moods),
  );

  bool get loading => _loading;
  List<MoodType> get moods => List.unmodifiable(_moods);

  /// Resuelve el estado en O(1). Si el estado fue eliminado del catálogo
  /// pero todavía hay registros antiguos que lo referencian, se devuelve
  /// un estado "desconocido" en vez de romper la pantalla.
  MoodType byId(String id) =>
      _byId[id] ?? const MoodType(id: '_unknown', label: 'Eliminado', emoji: '❔', color: Color(0xFF9AA5B1));

  void _rebuildIndex() {
    _byId = {for (final m in _moods) m.id: m};
  }

  /// Fuerza la escritura pendiente (si la hay). Lo invoca el ciclo de
  /// vida de la app al pausarla/destruirla.
  Future<void> flushNow() => _persistence.flushNow();

  Future<void> load() async {
    _moods = await _repository.loadAll();
    _rebuildIndex();
    _loading = false;
    notifyListeners();
  }

  Future<void> addMood({required String label, required String emoji, required Color color}) async {
    final mood = MoodType(id: _uuid.v4(), label: label, emoji: emoji, color: color);
    _moods = [..._moods, mood];
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }

  Future<void> updateMood(String id, {String? label, String? emoji, Color? color}) async {
    _moods = _moods
        .map((m) => m.id == id ? m.copyWith(label: label, emoji: emoji, color: color) : m)
        .toList();
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }

  Future<void> deleteMood(String id) async {
    _moods = _moods.where((m) => m.id != id).toList();
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }
}
