import 'package:flutter/material.dart';
import 'models/mood_type.dart';

/// Estados de ánimo por defecto, usados solo para "sembrar" el catálogo
/// la primera vez que se abre la app. Después de eso, el catálogo real
/// vive en [MoodCatalogProvider] y el usuario puede agregar, editar o
/// eliminar estados libremente (spec §1). Colores vívidos tomados del
/// referente `colorejemplo.jpeg`.
class MoodCatalog {
  static const List<MoodType> defaults = [
    MoodType(id: 'feliz', label: 'Feliz', emoji: '😊', color: Color(0xFFFFC501)),
    MoodType(id: 'triste', label: 'Triste', emoji: '😢', color: Color(0xFF1D8FFF)),
    MoodType(id: 'ansioso', label: 'Ansioso', emoji: '😰', color: Color(0xFFF3ABFE)),
    MoodType(id: 'enojado', label: 'Enojado', emoji: '😡', color: Color(0xFFFD6B6B)),
    MoodType(id: 'neutral', label: 'Neutral', emoji: '😐', color: Color(0xFF57B634)),
    MoodType(id: 'cansado', label: 'Cansado', emoji: '😴', color: Color(0xFFAA8DF6)),
  ];
}

/// Paleta curada para el selector de color del editor de estados, derivada
/// de `colorejemplo.jpeg`: misma familia de tonos e intensidad vívida que
/// ese referente (verde 57B634, cian 01E6FE, amarillo FFC501, coral
/// FE8050, violeta AA8DF6, azul 1D8FFF, rosa F3ABFE, ...).
class MoodColorPalette {
  static const List<Color> options = [
    Color(0xFFFD6B6B),
    Color(0xFFFE8050),
    Color(0xFFFEA501),
    Color(0xFFFFC501),
    Color(0xFFA7FF7C),
    Color(0xFF57B634),
    Color(0xFF18E586),
    Color(0xFF01E6FE),
    Color(0xFF1D8FFF),
    Color(0xFFAA8DF6),
    Color(0xFFF3ABFE),
    Color(0xFFFDA2AE),
  ];
}
