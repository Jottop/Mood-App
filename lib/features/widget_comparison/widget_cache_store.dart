import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/day_bubble_data.dart';

/// Storage compartido Flutter ⇄ Kotlin del widget de comparación.
///
/// Flutter escribe (app en primer plano, en cada publicacion) y las tareas
/// de fondo (WorkManager / futuro FCM) refrescan; en Android,
/// `MoodComparisonProvider` lee los mismos valores del widget storage de
/// home_widget (archivo "HomeWidgetPreferences") para DIBUJAR las burbujas
/// en nativo, sin volver a rasterizar con el motor Flutter.

// Sesión del usuario guardada en prefs planas para las tareas de fondo.
const kAuthSessionSnapshotKey = 'auth_session_snapshot';

// Amigo elegido (mismas claves históricas de compartir el snapshot).
const kWidgetPrefFriendId = 'widget_comparison_friend_id';
const kWidgetPrefFriendName = 'widget_comparison_friend_name';
const kWidgetPrefFriendEntries = 'widget_comparison_friend_entries';
const kWidgetPrefFriendCatalog = 'widget_comparison_friend_catalog';

// Heartbeat de la app en primer plano (epoch millis): la tarea de fondo lo
// lee para NO consultar al servidor mientras la app está activa (ahí el
// widget ya se mantiene al día desde Flutter).
const kWidgetPrefAppActiveAt = 'widget_app_active_at';

// Token de SOLO LECTURA del widget de comparación (emitido por la Edge
// Function `widget_token` con la sesión en primer plano). La tarea de fondo
// lo presenta a `widget_friend_bubble` para traer la burbuja del amigo SIN
// tocar el refresh token de la sesión: antes lo rotaba con la app cerrada y
// dejaba la app abierta con un token ya consumido (sesión perdida cada X
// min/horas). Mismo nivel de "secret" que el snapshot viejo: prefs planas.
const kWidgetComparisonToken = 'widget_comparison_token';

/// Lee el token de solo lectura del widget guardado en prefs (o null).
Future<String?> readWidgetComparisonToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(kWidgetComparisonToken);
  return token == null || token.isEmpty ? null : token;
}

/// Guarda el token de solo lectura del widget en prefs planas.
Future<void> saveWidgetComparisonToken(String token) async {
  if (token.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kWidgetComparisonToken, token);
}

/// Borra la copia local del token (al cerrar sesión o al invalidarlo).
Future<void> clearWidgetComparisonToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kWidgetComparisonToken);
}

// Cache de la escena consumido por el pintor nativo (JSON).
const kWidgetDateKey = 'widget_date_key';
const kWidgetMineJson = 'widget_mine_json';
const kWidgetFriendJson = 'widget_friend_json';

// Color de fondo del widget (ARGB) que el painter nativo rasteriza como
// tarjeta redondeada detrás de las burbujas. Ausente (= -1 en Kotlin) = el
// degradado clásico por defecto.
const kWidgetBgArgb = 'widget_bg_argb';

// Proveedores AppWidget que deben repintarse (horizontal y vertical).
const kWidgetProviderName = 'com.example.mood_app.MoodComparisonProvider';
const kWidgetVerticalProviderName = 'com.example.mood_app.MoodVerticalProvider';

// Clave local de un día en formato compacto 'yyyy-MM-dd'.
String widgetDateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _bubbleJson(String label, DayBubbleData data) => jsonEncode({
      'l': label,
      'c': [for (final c in data.colorsTopToBottom) c.toARGB32()],
      'a': [for (final c in data.auraColors) c.toARGB32()],
      'e': !data.isEmpty,
    });

/// Guarda la fecha a la que corresponde el cache actual.
Future<void> saveWidgetDateKey(String dateKey) =>
    HomeWidget.saveWidgetData(kWidgetDateKey, dateKey);

/// Guarda la burbuja "mía". Vacía por defecto (p. ej. al cambiar el día sin
/// abrir la app, donde no se puede recalcular en segundo plano).
Future<void> saveWidgetMine({
  DayBubbleData mine = const DayBubbleData(colorsTopToBottom: []),
  String label = 'Yo',
}) =>
    HomeWidget.saveWidgetData(kWidgetMineJson, _bubbleJson(label, mine));

/// Guarda la burbuja del amigo.
Future<void> saveWidgetFriend({
  required DayBubbleData friend,
  required String label,
}) =>
    HomeWidget.saveWidgetData(kWidgetFriendJson, _bubbleJson(label, friend));

/// Guarda el color de fondo elegido para el widget (ARGB). El painter nativo
/// lo convierte en el degradado de la tarjeta; sin él usa el clásico.
Future<void> saveWidgetBackground(int argb) =>
    HomeWidget.saveWidgetData(kWidgetBgArgb, argb);

/// Pide a Android que repinte los AppWidget (horizontal y vertical) con el
/// cache recién escrito.
Future<void> refreshWidgetPreview() async {
  await HomeWidget.updateWidget(
    qualifiedAndroidName: kWidgetProviderName,
  );
  await HomeWidget.updateWidget(
    qualifiedAndroidName: kWidgetVerticalProviderName,
  );
}