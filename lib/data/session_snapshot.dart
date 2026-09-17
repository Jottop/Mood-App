import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/widget_comparison/widget_cache_store.dart';

/// Snapshot de sesión (access + refresh token) en prefs planas, usado solo
/// por la app para recuperar la sesión más reciente al ARRANCAR en frío (la
/// tarea de fondo del widget ya NO rota tokens: usa el token de solo lectura
/// de `widget_token` y nunca toca la sesión).
///
/// La app escribía aquí en cada login/refresco de token; la tarea de fondo
/// antes rotaba el refresh token compartido con la app abierta (y eso
/// deslogueaba la sesión cada X min/horas). Hoy la app lo usa de forma
/// defensiva: si una rotación quedó a medias (p. ej. el proceso se cerró en
/// pleno refresh), el arranque adopta el token más reciente del snapshot en
/// vez de refrescar con uno ya consumido. Ver `AuthProvider`.

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