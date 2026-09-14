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
  /// personalizado deriva una versión más oscura abajo para conservar la
  /// identidad de doble tono.
  static List<Color> bgGradient(Color? top) {
    if (top == null || top == bgTop) return [bgTop, bgBottom];
    return [top, Color.lerp(top, const Color(0xFF18344D), 0.20)!];
  }
}
