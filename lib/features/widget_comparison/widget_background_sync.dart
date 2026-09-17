import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config/env.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../services/network_timeout.dart';
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
/// mantiene el widget al día y no vale la pena volver a llamar al servidor).
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
/// Con la app cerrada recuerda la sesión mediante el **token de solo
/// lectura** que la app emitió en primer plano (Edge Function `widget_token`,
/// guardado en prefs) y pide a la Edge Function `widget_friend_bubble` la
/// burbuja del amigo, recalcula su burbuja de HOY y deja el cache que dibuja
/// el widget nativo. Reglas:
///
///  * Si no hay sesión, amigo o red → deja el último cache intacto (no rompe
///    el widget) y termina.
///  * Si el cache corresponde a otro día → la burbuja "mía" se resetea a
///    vacía (no puede recalcularse sin la app) y se refresca la del amigo.
///  * Si el token ya no sirve (401) o la amistad se rompió (403) → se limpia
///    el token local (el próximo arranque de la app emite uno nuevo) y se
///    termina.
///
/// IMPORTANTE: esta tarea NUNCA toca el refresh token de la sesión. Antes lo
/// rotaba con `setSession` (mismo token compartido con la app abierta) y eso
/// invalidaba el que conserva la app → la sesión "se perdía" cada X min/horas.
///
/// La cadena se mantiene viva mientras haya amigo elegido: cada corrida
/// re-agenda el siguiente eslabón en [scheduleNextWidgetSync]. Sin amigo, la
/// tarea no se re-agenda (no vale la pena despertar el dispositivo para un
/// no-op) y main / la pantalla del widget la replantan al configurar uno.
Future<bool> runWidgetBackgroundSync() async {
  // Se decide tras conocer el amigo: mientras haya uno, la cadena sigue.
  var keepChain = false;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (!Env.isSupabaseConfigured) return false;

    final prefs = await SharedPreferences.getInstance();
    final friendId = prefs.getString(kWidgetPrefFriendId) ?? '';
    final friendName = prefs.getString(kWidgetPrefFriendName) ?? '—';
    if (friendId.isEmpty) return true;
    keepChain = true;

    // Si la app estuvo activa recientemente, el widget ya se mantiene al día
    // desde Flutter (publicaciones + refresco cada minuto) y no tiene sentido
    // llamar al servidor por la burbuja del amigo.
    final lastActiveAt = prefs.getInt(kWidgetPrefAppActiveAt) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - lastActiveAt <
        _appAliveWindow.inMilliseconds) {
      return true;
    }

    // Token de solo lectura emitido por la app (nunca la sesión real).
    final widgetToken = prefs.getString(kWidgetComparisonToken) ?? '';
    if (widgetToken.isEmpty) return true;

    final client = SupabaseClient(Env.supabaseUrl, Env.supabasePublishableKey);
    final res = await client.functions.invoke(
      'widget_friend_bubble',
      body: {'token': widgetToken, 'friendId': friendId},
    );
    final data = res.data;
    final entriesRows = data is Map<String, dynamic>
        ? data['entries']
        : null;
    final catalogRows = entriesRows is List ? data!['catalog'] : null;
    if (entriesRows is! List || catalogRows is! List) return true;

    final friendMood = friendMoodViewDataFromRows(
      entriesRows: entriesRows,
      catalogRows: catalogRows,
    );

    final today = DateTime.now();
    final dateKey = widgetDateKey(today);
    // La fecha se lee del MISMO store donde la escribe la app
    // (`HomeWidget.saveWidgetData`, vía [saveWidgetDateKey]): leerla de prefs
    // planas daba SIEMPRE null y la tarea reseteaba la burbuja mía en cada
    // corrida. Esta clave no existe en prefs planas.
    final currentDateKey =
        await HomeWidget.getWidgetData<String?>(kWidgetDateKey);
    // El día cambió sin abrir la app: la burbuja propia no se puede
    // recalcular en segundo plano → se deja vacía hasta que se abra.
    if (currentDateKey != dateKey) {
      await saveWidgetMine();
    }
    await saveWidgetDateKey(dateKey);
    await saveWidgetFriend(
      friend: dayBubbleData(friendMood, today),
      label: friendName,
    );
    await refreshWidgetPreview();
    return true;
  } on FunctionsHttpException catch (e) {
    // Token inválido (401) o amistad rota (403): se limpia el token local
    // para que el próximo arranque de la app emita uno nuevo; el widget se
    // queda con el último cache. Otros códigos (500, etc.) solo conservan el
    // cache y reintentan en el siguiente eslabón.
    if (e.status == 401 || e.status == 403) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kWidgetComparisonToken);
    }
    return true;
  } catch (_) {
    // Sin red, RLS fallando o lo que sea: se mantiene el último cache.
    return true;
  } finally {
    // Re-agenda SIEMPRE (éxito y errores): la cadena nunca se muere sola
    // mientras haya amigo. `replace` evita apilar eslabones; sin red o con
    // token inválido el siguiente eslabón reintentará más tarde. Un fallo al
    // agendar no debe marcar fallida una corrida que ya refrescó bien: la
    // excepción se traga (el cache quedó escrito).
    if (keepChain) {
      try {
        await scheduleNextWidgetSync();
      } catch (_) {}
    }
  }
}

/// Garantiza que exista el token de solo lectura del widget para la sesión
/// actual y devuelve el valor guardado en prefs. Es "cache-first": si ya hay
/// copia local no se llama al servidor (la Edge Function `widget_token`
/// siempre emite uno nuevo, así que no hay que rotarlo sin motivo). Si falta,
/// la pide con la sesión en primer plano y la persiste. Best-effort: devuelve
/// null si no hay red, sesión o configuración, sin lanzar.
Future<String?> ensureWidgetComparisonToken() async {
  final existing = await readWidgetComparisonToken();
  if (existing != null) return existing;
  if (!Env.isSupabaseConfigured) return null;
  try {
    final res = await withSupabaseTimeout(
      () => Supabase.instance.client.functions.invoke(
        'widget_token',
        body: const {'action': 'rotate'},
      ),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await saveWidgetComparisonToken(token);
        return token;
      }
    }
    return null;
  } catch (_) {
    // Sin red o la función no responde: el widget sigue con el último cache
    // y el próximo arranque reintenta.
    return null;
  }
}

/// Rota (invalida) en el servidor el token del widget de la sesión actual.
/// Se usa al cerrar sesión (best-effort), mientras la sesión sigue siendo
/// válida, para que una copia local que quedara no se pueda reutilizar. La
/// copia local se limpia igual en el flujo de cierre.
Future<void> rotateWidgetComparisonToken() async {
  if (!Env.isSupabaseConfigured) return;
  try {
    await withSupabaseTimeout(
      () => Supabase.instance.client.functions.invoke(
        'widget_token',
        body: const {'action': 'rotate'},
      ),
    );
  } catch (_) {
    // Sin red: la copia local ya se limpia en el cierre de sesión.
  }
}