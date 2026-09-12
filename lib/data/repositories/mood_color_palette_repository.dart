/// Estado persistido de la paleta extendida de colores "elegibles" del
/// editor de estados: los colores personalizados agregados por el usuario
/// y los colores base que decidió ocultar. Se guarda por dispositivo
/// (SharedPreferences, preferencia de UI local; no se sincroniza con la
/// nube, igual que el patrón de los demás repositorios locales).
class MoodColorPaletteState {
  /// Valores ARGB de los colores personalizados agregados por el usuario.
  final List<int> custom;

  /// Valores ARGB de los colores base que el usuario quitó de la paleta.
  final List<int> removedBase;

  const MoodColorPaletteState({this.custom = const [], this.removedBase = const []});

  MoodColorPaletteState copyWith({List<int>? custom, List<int>? removedBase}) =>
      MoodColorPaletteState(
        custom: custom ?? this.custom,
        removedBase: removedBase ?? this.removedBase,
      );

  Map<String, dynamic> toJson() => {
        'custom': custom,
        'removed_base': removedBase,
      };

  factory MoodColorPaletteState.fromJson(Map<String, dynamic> json) => MoodColorPaletteState(
        custom: (json['custom'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
        removedBase:
            (json['removed_base'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
      );
}

/// Persistencia de la paleta de colores elegibles del editor de estados.
abstract class MoodColorPaletteRepository {
  Future<MoodColorPaletteState> load();

  Future<void> save(MoodColorPaletteState state);
}