import 'dart:convert';

import 'package:home_widget/home_widget.dart';

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
// lee para NO consumir el refresh token compartido mientras la app está
// activa (ahí el widget ya se mantiene al día desde Flutter).
const kWidgetPrefAppActiveAt = 'widget_app_active_at';

// Cache de la escena consumido por el pintor nativo (JSON).
const kWidgetDateKey = 'widget_date_key';
const kWidgetMineJson = 'widget_mine_json';
const kWidgetFriendJson = 'widget_friend_json';

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