import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFFEAF3FC);
  static const bgBottom = Color(0xFFDCEAFB);
  static const ink = Color(0xFF2B3A4A);
  static const inkSoft = Color(0xFF5E7181);
  static const card = Colors.white;
  static const cardLine = Color(0xFFE3ECF5);
  static const cream = Color(0xFFFBF3DE);
  static const creamInk = Color(0xFF7A6A3F);
  static const logoBg = Color(0xFFFBEEDC);

  /// Gradiente de fondo de Home y perfiles. Con [top] nulo o igual al
  /// [bgTop] por defecto usa el gradiente estándar de la app; con un color
  /// personalizado deriva una versión del MISMO color levemente más profunda
  /// (mismo matiz y saturación, solo algo menos claro), para que el degradado
  /// se vea suave y sin manchas oscuras ni suciedad.
  static List<Color> bgGradient(Color? top) {
    if (top == null || top == bgTop) return [bgTop, bgBottom];
    final hsl = HSLColor.fromColor(top);
    final bottom =
        hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
    return [top, bottom];
  }
}
