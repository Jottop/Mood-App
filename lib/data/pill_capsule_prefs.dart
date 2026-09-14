import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// Fondo de la cápsula del hub de amigos ("pastilla de amigos"): un color
/// SOLO local (SharedPreferences), visible únicamente en este dispositivo,
/// a diferencia de los colores de la píldora/perfil que sí van al backend.
const _kCapsuleBgKey = 'pill_capsule_bg';

/// Notificador global del color de la cápsula. Es un `ValueNotifier` de
/// nivel superior (no un provider) porque el overlay del hub vive por
/// encima del Navigator y necesita reaccionar a cambios hechos en
/// Editar perfil sin re-wirear `main.dart`.
final ValueNotifier<Color> pillCapsuleBg = ValueNotifier<Color>(AppColors.card);

/// Lee el color guardado de las preferencias y lo publica en
/// [pillCapsuleBg]. Se llama una vez al arrancar el overlay del hub.
Future<void> loadPillCapsuleBg() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getInt(_kCapsuleBgKey);
  if (raw != null) {
    pillCapsuleBg.value = Color(raw);
  }
}

/// Guarda el color de la cápsula: actualiza el notificador (para que el hub
/// y la preview de Editar perfil reaccionen al instante) y lo persiste.
Future<void> savePillCapsuleBg(Color color) async {
  pillCapsuleBg.value = color;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kCapsuleBgKey, color.toARGB32());
}
