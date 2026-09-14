import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../core/widgets/day_bubble_data.dart';

/// Storage compartido Flutter ⇄ Kotlin del widget de comparación.
///
/// Flutter escribe (app en primer plano, en cada publicacion) y las tareas
/// de fondo (WorkManager) refrescan; en Android, `MoodComparisonProvider`
/// lee los mismos valores del widget storage de home_widget (archivo
/// "HomeWidgetPreferences") para DIBUJAR las burbujas en nativo, sin volver
/// a rasterizar con el motor Flutter.

// Sesión del usuario guardada en prefs planas para las tareas de fondo.
const kAuthSessionSnapshotKey = 'auth_session_snapshot';

// Selección del widget (hasta 2 amigos; la 1.ª burbuja es siempre "Yo") +
// disposición. Viven en prefs planas: las lee la app para configurar y la
// tarea de fondo para re-publicar.
const kWidgetPrefFriendIds = 'widget_comparison_friend_ids';
const kWidgetPrefFriendNames = 'widget_comparison_friend_names';
const kWidgetPrefFriendSnapshots = 'widget_comparison_friend_snapshots';
const kWidgetPrefLayout = 'widget_comparison_layout';

// Claves legacy (instalaciones previas con "1 amigo") para migrar la
// configuración antigua a la lista nueva.
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
const kWidgetBubblesJson = 'widget_bubbles_json';
const kWidgetLayout = 'widget_layout';

// Proveedor AppWidget que debe repintarse.
const kWidgetProviderName = 'com.example.mood_app.MoodComparisonProvider';

/// Disposición de las burbujas en el widget del escritorio.
enum WidgetLayout {
  /// Burbujas lado a lado (escena ancha, por defecto).
  horizontal,

  /// Burbujas apiladas de arriba a abajo (escena en retrato).
  vertical,
}

/// Parsea la clave de layout ('h'/'v') con 'h' como valor por defecto.
WidgetLayout widgetLayoutFromKey(String? key) =>
    key == 'v' ? WidgetLayout.vertical : WidgetLayout.horizontal;

/// Clave compacta de un layout ('h'/'v') para el storage del widget.
String widgetLayoutKey(WidgetLayout layout) =>
    layout == WidgetLayout.vertical ? 'v' : 'h';

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

/// Guarda la escena completa del widget: la lista de burbujas en orden de
/// aparición (la 1.ª siempre es "Yo") y la disposición elegida. El AppWidget
/// nativo la dibuja tal cual.
Future<void> saveWidgetScene({
  required List<({String label, DayBubbleData data})> bubbles,
  required WidgetLayout layout,
}) async {
  await HomeWidget.saveWidgetData(
    kWidgetBubblesJson,
    jsonEncode([
      for (final b in bubbles) _bubbleJson(b.label, b.data),
    ]),
  );
  await HomeWidget.saveWidgetData(kWidgetLayout, widgetLayoutKey(layout));
}

/// Pide a Android que repinte el AppWidget con el cache recién escrito.
Future<void> refreshWidgetPreview() => HomeWidget.updateWidget(
      qualifiedAndroidName: kWidgetProviderName,
    );