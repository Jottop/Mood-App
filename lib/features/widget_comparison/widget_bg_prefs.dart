import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_cache_store.dart';

/// Color de fondo del widget del escritorio: SOLO local (SharedPreferences +
/// storage del widget), elegido en la configuración del widget con las mismas
/// opciones que el fondo del perfil (presets + color personalizado).
/// `null` = degradado clásico por defecto (sin personalizar).
const _kWidgetBgPref = 'widget_bg_argb';

/// Notificador global del color de fondo del widget. `null` significa que no
/// se personalizó (el pintor nativo usa el degradado clásico).
final ValueNotifier<Color?> widgetBgColor = ValueNotifier<Color?>(null);

/// Lee el color guardado de las preferencias y lo publica en [widgetBgColor].
/// Se llama al iniciar el `WidgetComparisonService`.
Future<void> loadWidgetBgColor() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getInt(_kWidgetBgPref);
  if (raw != null) {
    widgetBgColor.value = Color(raw);
  }
}

/// Guarda el color de fondo del widget: notifica (para que la pantalla de
/// configuración repinte las previews al instante), lo persiste en prefs y en
/// el storage del widget y le pide a Android que repinte ambos AppWidget.
///
/// Al storage del widget va como cadena hex (no como int): un ARGB opaco
/// (> [Int32].MAX_VALUE) el plugin de home_widget lo guardaría como Long y
/// rompería el `getInt` nativo (crash histórico). El pintor nativo lo lee con
/// defensa (ver `widgetBackgroundArgb` en Kotlin).
Future<void> saveWidgetBackgroundColor(Color color) async {
  final argb = color.toARGB32();
  widgetBgColor.value = color;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWidgetBgPref, argb);
  await saveWidgetBackground(argb);
  await refreshWidgetPreview();
}