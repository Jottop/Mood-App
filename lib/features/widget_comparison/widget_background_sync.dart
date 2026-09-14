import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config/env.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/session_snapshot.dart';
import 'widget_cache_store.dart';

const kWidgetSyncTaskName = 'widgetBubbleSync';

// Id único de la tarea. Se reutiliza para TODA la cadena de one-off (así
// main la puede cancelar de una).
const kWidgetSyncPeriodicTask = 'widget-bubble-sync';

/// Cadencia de la cadena de refresco en segundo plano. Los trabajos
/// PERIÓDICOS de WorkManager exigen mínimo 15 min; esta cadena usa one-off
/// re-agendados, que no tienen ese mínimo. Doze puede estirar la espera real
/// cuando el dispositivo lleva rato en reposo.
const kWidgetSyncCadence = Duration(minutes: 5);

/// Ventana en la que se considera que la app estuvo viva recientemente: si el
/// heartbeat es más reciente que esto, la tarea de fondo se salta (la app ya
/// mantiene el widget al día, y consumir el token compartido desloguearía).
/// Se alinea con [kWidgetSyncCadence]: el salto no debe vuelcar la cadencia.
const _appAliveWindow = kWidgetSyncCadence;

/// Agenda el siguiente eslabón de la cadena de refresco. Mismo [uniqueName]
/// con [ExistingWorkPolicy.replace]: si quedaba un eslabón pendiente se
/// reemplaza, nunca se acumulan.
Future<void> scheduleNextWidgetSync() async {
  await Workmanager().registerOneOffTask(
    kWidgetSyncPeriodicTask,
    kWidgetSyncTaskName,
    initialDelay: kWidgetSyncCadence,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// `callbackDispatcher` de WorkManager: corre en un aislado Flutter aun con
/// la app cerrada. No puede tocar providers ni el árbol: se limita a
/// refrescar la burbuja del amigo y pedirle al widget que se repinte.
@pragma('vm:entry-point')
void widgetBackgroundCallbackDispatcher() {
  Workmanager().executeTask(
    (taskName, inputData) => runWidgetBackgroundSync(),
  );
}

/// Tarea de fondo del widget de comparación.
///
/// Con la app cerrada recuerda la sesión (snapshot en prefs planas) y trae
/// el snapshot del amigo, recalcula su burbuja de HOY y deja el cache que
/// dibuja el widget nativo. Reglas:
///
///  * Si no hay sesión, amigo o red → deja el último cache intacto (no rompe
///    el widget) y termina.
///  * Si el cache corresponde a otro día → la burbuja "mía" se resetea a
///    vacía (no puede recalcularse sin la app) y se refresca la del amigo.
///  * Si el refresh token ya no sirve → se limpia el snapshot (así el
///    próximo arranque pide login de nuevo) y se termina.
///
/// La cadena se mantiene viva mientras haya amigo elegido: cada corrida
/// re-agenda el siguiente eslabón en [scheduleNextWidgetSync]. Sin amigo, la
/// tarea no se re-agenda (no vale la pena despertar el dispositivo para un
/// no-op) y main / la pantalla del widget la replantan al configurar uno.
Future<bool> runWidgetBackgroundSync() async {
  // Se decide tras conocer los amigos: mientras haya alguno, la cadena sigue.
  var keepChain = false;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (!Env.isSupabaseConfigured) return false;

    final prefs = await SharedPreferences.getInstance();
    var friendIds = _jsonStringList(prefs.getString(kWidgetPrefFriendIds));
    var friendNames = _jsonStringList(prefs.getString(kWidgetPrefFriendNames));
    // Migración: instalaciones viejas guardaban un solo amigo en claves
    // planas.
    final legacyId = prefs.getString(kWidgetPrefFriendId) ?? '';
    if (friendIds.isEmpty && legacyId.isNotEmpty) {
      friendIds = [legacyId];
      friendNames = [prefs.getString(kWidgetPrefFriendName) ?? '—'];
    }
    if (friendIds.length != friendNames.length) {
      friendNames = List.filled(friendIds.length, '—');
    }
    if (friendIds.isEmpty) return true;
    final layout = widgetLayoutFromKey(prefs.getString(kWidgetPrefLayout));
    keepChain = true;

    // Si la app estuvo activa recientemente, el widget ya se mantiene al día
    // desde Flutter (publicaciones + refresco cada minuto) y este refresco
    // consumiría el refresh token compartido, rotándolo y pudiendo
    // desloguear la sesión principal.
    final lastActiveAt = prefs.getInt(kWidgetPrefAppActiveAt) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - lastActiveAt <
        _appAliveWindow.inMilliseconds) {
      return true;
    }

    final snapshotJson = prefs.getString(kAuthSessionSnapshotKey) ?? '';
    if (snapshotJson.isEmpty) return true;
    final Map<String, dynamic> session;
    try {
      session = jsonDecode(snapshotJson) as Map<String, dynamic>;
    } catch (_) {
      return true;
    }
    final refreshToken = session['refreshToken'] as String?;
    if (refreshToken == null || refreshToken.isEmpty) return true;

    final client = SupabaseClient(Env.supabaseUrl, Env.supabasePublishableKey);
    try {
      // Renueva el access token usando el refresh token guardado.
      await client.auth.setSession(refreshToken);
      // `setSession` ROTA el refresh token: se guarda de vuelta en el
      // snapshot para que la próxima tarea use el token vigente (si no, el
      // siguiente intento con el ya consumido fallaría y esto limpiaría la
      // sesión de fondo).
      await persistSessionSnapshot(client.auth.currentSession);
    } catch (_) {
      // Tokens rechazados/vencidos: sin credenciales válidas no hay nada
      // que refrescar.
      await prefs.remove(kAuthSessionSnapshotKey);
      return true;
    }

    final today = DateTime.now();
    final dateKey = widgetDateKey(today);
    // La fecha se lee del MISMO store donde la escribe la app
    // (`HomeWidget.saveWidgetData`, vía [saveWidgetDateKey]): leerla de prefs
    // planas daba SIEMPRE null y la tarea reseteaba la burbuja mía en cada
    // corrida. Esta clave no existe en prefs planas.
    final currentDateKey =
        await HomeWidget.getWidgetData<String?>(kWidgetDateKey);
    // Burbuja propia: la app siempre la publica estando en primer plano; en
    // segundo plano no se puede recalcular. Si el día NO cambió se conserva
    // la que dejó la app, y si cambió se deja vacía hasta que se abra.
    final bubbles = <({String label, DayBubbleData data})>[];
    final storedMine = await _storedMineBubble();
    if (currentDateKey == dateKey && storedMine != null) {
      bubbles.add(storedMine);
    } else {
      bubbles.add((
        label: 'Yo',
        data: const DayBubbleData(colorsTopToBottom: []),
      ));
    }
    for (var i = 0; i < friendIds.length; i++) {
      final friendMood =
          await fetchFriendMoodViewData(friendIds[i], client: client);
      bubbles.add((
        label: friendNames[i],
        data: dayBubbleData(friendMood, today),
      ));
    }
    await saveWidgetDateKey(dateKey);
    await saveWidgetScene(bubbles: bubbles, layout: layout);
    await refreshWidgetPreview();
    return true;
  } catch (_) {
    // Sin red, RLS fallando o lo que sea: se mantiene el último cache.
    return true;
  } finally {
    // Re-agenda SIEMPRE (éxito y errores): la cadena nunca se muere sola
    // mientras haya amigos. `replace` evita apilar eslabones; sin red o con
    // tokens rotos el siguiente eslabón reintentará más tarde. Un fallo al
    // agendar no debe marcar fallida una corrida que ya refrescó bien: la
    // excepción se traga (el cache quedó escrito).
    if (keepChain) {
      try {
        await scheduleNextWidgetSync();
      } catch (_) {}
    }
  }
}

List<String> _jsonStringList(String? raw) {
  if (raw == null) return const [];
  try {
    return [
      for (final item in jsonDecode(raw) as List)
        if (item is String && item.isNotEmpty) item,
    ];
  } catch (_) {
    return const [];
  }
}

/// Lee la burbuja "mía" (la 1.ª del array) que dejó la app publicada en el
/// widget storage, para conservarla cuando el día no cambió. Devuelve null si
/// aún no hay nada publicado.
Future<({String label, DayBubbleData data})?> _storedMineBubble() async {
  final json = await HomeWidget.getWidgetData<String?>(kWidgetBubblesJson);
  if (json == null) return null;
  try {
    final array = jsonDecode(json) as List;
    if (array.isEmpty) return null;
    final map = array.first as Map<String, dynamic>;
    return (
      label: map['l'] as String? ?? 'Yo',
      data: _bubbleDataFromJson(map),
    );
  } catch (_) {
    return null;
  }
}

DayBubbleData _bubbleDataFromJson(Map<String, dynamic> map) {
  final colors = <Color>[];
  final aura = <Color>[];
  for (final c in map['c'] as List? ?? const []) {
    colors.add(Color((c as num).toInt()));
  }
  for (final a in map['a'] as List? ?? const []) {
    aura.add(Color((a as num).toInt()));
  }
  return DayBubbleData(colorsTopToBottom: colors, auraColors: aura);
}