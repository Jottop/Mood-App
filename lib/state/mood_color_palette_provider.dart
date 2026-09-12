import 'package:flutter/material.dart';

import '../data/mood_catalog.dart';
import '../data/repositories/mood_color_palette_repository.dart';
import 'debounced_persistence.dart';

/// Colores "elegibles" del editor de estados: la paleta curada por defecto
/// ([MoodColorPalette.options]) más los colores personalizados que el
/// usuario va eligiendo con el selector libre, y menos los colores base
/// que decidió ocultar. Un color elegido ahí queda guardado por dispositivo
/// y aparece como opción rápida la próxima vez (spec: edición sencilla del
/// catálogo, sin repetir el camino largo). Con "Restaurar originales" se
/// vuelve a la paleta curada de fábrica.
class MoodColorPaletteProvider extends ChangeNotifier {
  MoodColorPaletteProvider({required MoodColorPaletteRepository repository}) : _repository = repository;

  final MoodColorPaletteRepository _repository;

  /// Tope de colores personalizados retenidos por dispositivo.
  static const int maxCustomColors = 24;

  List<int> _custom = [];
  List<int> _removed = [];
  bool _loading = true;

  late final DebouncedPersistence _persistence = DebouncedPersistence(() => _repository.save(_state));

  bool get loading => _loading;

  List<Color> get customColors => List.unmodifiable(_custom.map(Color.new));

  /// Estado completo tal como se persiste.
  MoodColorPaletteState get _state => MoodColorPaletteState(custom: _custom, removedBase: _removed);

  /// `true` si el usuario tocó la paleta (agregó o quitó colores): es
  /// cuando tiene sentido ofrecer "Restaurar originales".
  bool get isModified => _custom.isNotEmpty || _removed.isNotEmpty;

  /// Paleta completa visible en el editor: base curada (menos los colores
  /// que el usuario ocultó) + personalizados.
  List<Color> get all => [
        ...MoodColorPalette.options.where((c) => !_removed.contains(c.toARGB32())),
        ...customColors,
      ];

  Future<void> load() async {
    final state = await _repository.load();
    _custom = state.custom;
    _removed = state.removedBase;
    _loading = false;
    notifyListeners();
  }

  /// Fuerza la escritura pendiente (si la hay). Lo invoca el ciclo de vida
  /// de la app al pausarla/destruirla.
  Future<void> flushNow() => _persistence.flushNow();

  /// Registra un color personalizado como elegible. Si ya existe en la
  /// paleta (base o personalizados) se ignora; se conservan como máximo
  /// [maxCustomColors] colores, descartando los más antiguos.
  void addCustom(Color color) {
    final argb = color.toARGB32();
    if (all.any((c) => c.toARGB32() == argb)) return;
    _custom = [..._custom, argb];
    if (_custom.length > maxCustomColors) {
      _custom = _custom.sublist(_custom.length - maxCustomColors);
    }
    notifyListeners();
    _persistence.schedule();
  }

  /// Quita un color de la paleta visible: si es un color base de fábrica
  /// queda oculto (y "Restaurar originales" lo recupera); si es un color
  /// personalizado se elimina definitivamente. Un color base siempre queda
  /// registrado como oculto aunque estuviera re-agregado como personalizado.
  void removeColor(Color color) {
    final argb = color.toARGB32();
    _custom = _custom.where((c) => c != argb).toList();
    final isBase = MoodColorPalette.options.any((c) => c.toARGB32() == argb);
    if (isBase && !_removed.contains(argb)) {
      _removed = [..._removed, argb];
    }
    notifyListeners();
    _persistence.schedule();
  }

  /// Restaura la paleta a los colores originales por defecto: elimina los
  /// colores personalizados y vuelve a mostrar todos los colores base.
  void restoreDefault() {
    _custom = [];
    _removed = [];
    notifyListeners();
    _persistence.schedule();
  }
}