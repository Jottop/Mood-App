import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/widget_comparison/widget_cache_store.dart';

/// Snapshot de sesión (access + refresh token) en prefs planas, usado por
/// las tareas de fondo del widget (WorkManager), donde no hay
/// `FlutterSecureStorage`.
///
/// La app principal escribe aquí en cada login y en cada refresco de token;
/// las tareas de fondo escriben de vuelta el token rotado tras usarlo (ver
/// `widget_background_sync.dart`), así el snapshot siempre guarda el token
/// MÁS reciente de la cuenta y ninguna de las dos partes refresca con uno ya
/// consumido.

/// Lee el snapshot guardado (o null si no existe o está corrupto).
Future<Map<String, dynamic>?> readSessionSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(kAuthSessionSnapshotKey);
  if (json == null) return null;
  try {
    return jsonDecode(json) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Escribe (o sobreescribe) el snapshot con la sesión indicada.
Future<void> persistSessionSnapshot(Session? session) async {
  if (session == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kAuthSessionSnapshotKey,
    jsonEncode({
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      // `expiresAt` es un timestamp Unix (segundos), no un DateTime.
      'expiresAt': session.expiresAt,
    }),
  );
}

/// Borra el snapshot (al cerrar sesión o cuando los tokens quedan inválidos).
Future<void> clearSessionSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kAuthSessionSnapshotKey);
}