import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/emoji_pack.dart';
import '../data/models/mood_type.dart';
import '../data/models/trashed_mood.dart';
import '../data/repositories/local_trash_repository.dart';
import '../data/repositories/mood_catalog_repository.dart';
import '../data/repositories/sync_exception.dart';
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
  MoodCatalogProvider({required MoodCatalogRepository repository, TrashRepository? trashRepository})
      : _repository = repository,
        _trashRepository = trashRepository ?? LocalTrashRepository();

  final MoodCatalogRepository _repository;
  final TrashRepository _trashRepository;
  final _uuid = const Uuid();

  /// Máximo óptimo de emociones recomendado para que el selector siga
  /// siendo fluido. Superarlo no bloquea, solo advierte al usuario.
  static const int maxOptimalMoods = 10;

  /// Cuánto vive una emoción en la papelera antes de purgarse sola.
  static const Duration trashRetention = Duration(days: 7);

  List<MoodType> _moods = [];
  Map<String, MoodType> _byId = const {};
  bool _loading = true;
  String? _loadError;

  List<TrashedMood> _trash = const [];
  bool _trashLoaded = false;

  late final DebouncedPersistence _persistence = DebouncedPersistence(
    () => _repository.saveAll(_moods),
  );
  late final DebouncedPersistence _trashPersistence = DebouncedPersistence(
    () => _trashRepository.saveAll(_trash),
  );

  bool get loading => _loading;

  /// Error de la carga inicial (p. ej. sin conexión). Null si todo bien.
  String? get loadError => _loadError;
  List<MoodType> get moods => List.unmodifiable(_moods);

  /// Emociones en la papelera (las más recientes primero).
  List<TrashedMood> get trash => List.unmodifiable(
        [..._trash]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt)),
      );

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
  Future<void> flushNow() async {
    await _persistence.flushNow();
    await _trashPersistence.flushNow();
  }

  Future<void> load() async {
    _loadError = null;
    try {
      // Al cargar se sanea el emoji de cada estado (en memoria, sin tocar
      // la nube): los emojis fuera del pack se reencuadran a uno seguro para
      // que ningún teléfono muestre cajas vacías.
      _moods = (await _repository.loadAll())
          .map((m) => m.copyWith(emoji: EmojiPack.sanitize(m.emoji)))
          .toList();
      _rebuildIndex();
    } catch (e) {
      _loadError = e is SyncException ? e.message : 'No se pudo cargar tu catálogo de estados.';
    }
    _loading = false;
    await loadTrash();
    notifyListeners();
  }

  /// Carga la papelera local y purga lo vencido. Si ya estaba cargada solo
  /// purga (se llama al abrir la pantalla de papelera).
  Future<void> ensureTrashLoaded() async {
    if (!_trashLoaded) {
      await loadTrash();
      return;
    }
    final before = _trash.length;
    _purgeExpired();
    if (_trash.length != before) notifyListeners();
  }

  Future<void> loadTrash() async {
    try {
      _trash = (await _trashRepository.loadAll())
          .map((t) => TrashedMood(
                mood: t.mood.copyWith(emoji: EmojiPack.sanitize(t.mood.emoji)),
                deletedAt: t.deletedAt,
              ))
          .toList();
    } catch (_) {
      _trash = const [];
    }
    _trashLoaded = true;
    _purgeExpired();
    notifyListeners();
  }

  /// Descarta (y persiste) las emociones que ya cumplieron los 7 días.
  void _purgeExpired() {
    final now = DateTime.now();
    final before = _trash.length;
    _trash = _trash
        .where((t) => now.difference(t.deletedAt) < trashRetention)
        .toList();
    if (_trash.length != before) _trashPersistence.schedule();
  }

  /// Repite la carga inicial tras un error (pantalla de reintento).
  Future<void> retryLoad() {
    _loading = true;
    notifyListeners();
    return load();
  }

  /// Vuelve a leer el catálogo desde la nube (pull-to-refresh) sin tocar la
  /// pantalla de error: si falla, conserva el catálogo actual en memoria.
  Future<void> refresh() async {
    try {
      _moods = (await _repository.loadAll())
          .map((m) => m.copyWith(emoji: EmojiPack.sanitize(m.emoji)))
          .toList();
      _rebuildIndex();
    } catch (_) {
      // Sin red: se conserva el catálogo actual.
    }
    notifyListeners();
  }

  Future<void> addMood({
    required String label,
    required String emoji,
    required Color color,
    bool isSpecial = false,
  }) async {
    final mood = MoodType(id: _uuid.v4(), label: label, emoji: emoji, color: color, isSpecial: isSpecial);
    _moods = [..._moods, mood];
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }

  /// Reordena las emociones del catálogo (el nuevo orden se persiste y se
  /// refleja también en el selector rápido). Recibe un [newIndex] ya
  /// ajustado (semántica de `ReorderableListView.onReorderItem`).
  Future<void> reorderMoods(int oldIndex, int newIndex) async {
    final item = _moods[oldIndex];
    _moods = [..._moods]..removeAt(oldIndex)..insert(newIndex, item);
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }

  Future<void> updateMood(
    String id, {
    String? label,
    String? emoji,
    Color? color,
    bool? isSpecial,
  }) async {
    _moods = _moods
        .map((m) => m.id == id ? m.copyWith(label: label, emoji: emoji, color: color, isSpecial: isSpecial) : m)
        .toList();
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
  }

  /// Elimina una emoción del catálogo: pasa a la papelera local (de donde
  /// se puede restaurar hasta 7 días después). En la nube se borra por el
  /// diff normal de `saveAll`.
  Future<void> deleteMood(String id) async {
    final mood = _byId[id];
    _moods = _moods.where((m) => m.id != id).toList();
    _rebuildIndex();
    if (mood != null) {
      _trash = [..._trash, TrashedMood(mood: mood, deletedAt: DateTime.now())];
      _trashPersistence.schedule();
    }
    notifyListeners();
    _persistence.schedule();
  }

  /// Restaura una emoción desde la papelera (vuelve al final del catálogo
  /// con su id y configuración originales).
  Future<void> restoreMood(String id) async {
    final index = _trash.indexWhere((t) => t.mood.id == id);
    if (index < 0) return;
    final mood = _trash[index].mood;
    _trash = [..._trash]..removeAt(index);
    _moods = [..._moods, mood];
    _rebuildIndex();
    notifyListeners();
    _persistence.schedule();
    _trashPersistence.schedule();
  }

  /// Vacía la papelera por completo (las emociones se pierden para siempre).
  Future<void> emptyTrash() async {
    if (_trash.isEmpty) return;
    _trash = const [];
    notifyListeners();
    _trashPersistence.schedule();
  }
}
