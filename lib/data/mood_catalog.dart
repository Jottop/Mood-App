import 'package:flutter/material.dart';
import 'models/mood_type.dart';

/// Estados de ánimo por defecto, usados solo para "sembrar" el catálogo
/// la primera vez que se abre la app. Después de eso, el catálogo real
/// vive en [MoodCatalogProvider] y el usuario puede agregar, editar o
/// eliminar estados libremente (spec §1).
class MoodCatalog {
  static const List<MoodType> defaults = [
    MoodType(id: 'feliz', label: 'Feliz', emoji: '😊', color: Color(0xFFFFA000)),
    MoodType(id: 'triste', label: 'Triste', emoji: '😢', color: Color(0xFF1E88E5)),
    MoodType(id: 'ansioso', label: 'Ansioso', emoji: '😰', color: Color(0xFF8E24AA)),
    MoodType(id: 'enojado', label: 'Enojado', emoji: '😡', color: Color(0xFFE53935)),
    MoodType(id: 'neutral', label: 'Neutral', emoji: '😐', color: Color(0xFF43A047)),
    MoodType(id: 'cansado', label: 'Cansado', emoji: '😴', color: Color(0xFF5E35B1)),
  ];
}

/// Paleta curada para el selector de color del editor de estados:
/// variantes más saturadas y vivas que la anterior.
class MoodColorPalette {
  static const List<Color> options = [
    Color(0xFFFFA000),
    Color(0xFFFF6F00),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFBC02D),
    Color(0xFF6D4C41),
  ];
}
