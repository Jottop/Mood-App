import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config/env.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import 'widget_cache_store.dart';

const kWidgetSyncTaskName = 'widgetBubbleSync';
const kWidgetSyncPeriodicTask = 'widget-bubble-sync';

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
Future<bool> runWidgetBackgroundSync() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (!Env.isSupabaseConfigured) return false;

    final prefs = await SharedPreferences.getInstance();
    final friendId = prefs.getString(kWidgetPrefFriendId) ?? '';
    final friendName = prefs.getString(kWidgetPrefFriendName) ?? '—';
    if (friendId.isEmpty) return true;

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
    } catch (_) {
      // Tokens rechazados/vencidos: sin credenciales válidas no hay nada
      // que refrescar.
      await prefs.remove(kAuthSessionSnapshotKey);
      return true;
    }

    final friendMood = await fetchFriendMoodViewData(friendId, client: client);

    final today = DateTime.now();
    final dateKey = widgetDateKey(today);
    final currentDateKey = prefs.getString(kWidgetDateKey);
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
  } catch (_) {
    // Sin red, RLS fallando o lo que sea: se mantiene el último cache.
    return true;
  }
}