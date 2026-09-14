import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_update.dart';

/// Error controlado del flujo de descarga/instalación (mensaje para el user).
class UpdateDownloadException implements Exception {
  final String message;

  const UpdateDownloadException(this.message);

  @override
  String toString() => message;
}

/// Puente al `MethodChannel` nativo (`moodapp/installer`) que abre el
/// instalador nativo de Android (FileProvider + ACTION_VIEW), sin abrir el
/// navegador ni la página hub.
class AppInstaller {
  const AppInstaller();

  static const _channel = MethodChannel('moodapp/installer');

  /// ¿Android ya permite a CamiMood instalar aplicaciones? (Android 8+;
  /// en versiones anteriores el toggle es global y devuelve `true`).
  Future<bool> canRequestInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla del sistema para habilitar "Permitir instalar
  /// aplicaciones desconocidas" para CamiMood.
  Future<void> openInstallSettings() async {
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  /// Abre el instalador nativo de Android con el APK de la ruta dada
  /// (ACTION_VIEW + FileProvider). Android muestra su diálogo de confirmación
  /// y verifica el paquete; la app se cierra sola si se aplica la actualización.
  Future<void> launchInstaller(String path) async {
    await _channel.invokeMethod<void>('launchInstaller', {'path': path});
  }
}

/// Descarga el APK a la carpeta temporal de la app e informa el progreso.
/// Devuelve la ruta del archivo una vez verificada su integridad (SHA-256
/// contra el hub). Lanza [UpdateDownloadException] si algo falla o el archivo
/// no coincide con la firma oficial.
Future<String> downloadApk(
  AppUpdateInfo update, {
  required void Function(int received, int total, double fraction) onProgress,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/cami-${update.versionName}-${update.versionCode}.apk');

  // Sanea descargas viejas (evita acumular decenas de MB en caché).
  try {
    for (final entry in dir.listSync(followLinks: false)) {
      if (entry is File && entry.path.contains('cami-') && entry.path.endsWith('.apk')) {
        entry.deleteSync();
      }
    }
  } catch (_) {
    // No es crítico: si no se puede limpiar, continuamos.
  }

  final client = http.Client();
  try {
    final response = await client
        .send(http.Request('GET', Uri.parse(update.apkUrl)))
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      throw UpdateDownloadException(
        'No se pudo descargar la versión (HTTP ${response.statusCode}). Revisa tu conexión.',
      );
    }

    final total = response.contentLength ?? 0;
    int received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total, total > 0 ? received / total : 0);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      try {
        file.deleteSync();
      } catch (_) {}
      throw const UpdateDownloadException(
        'No se pudo completar la descarga. Revisa tu conexión.',
      );
    }
    await sink.close();
  } finally {
    client.close();
  }

  if (update.sha256.isNotEmpty) {
    final digest = sha256.convert(await file.readAsBytes()).toString();
    if (digest != update.sha256.toLowerCase()) {
      try {
        file.deleteSync();
      } catch (_) {}
      throw const UpdateDownloadException(
        'La descarga no coincide con la firma oficial. Reintenta en un rato.',
      );
    }
  }

  return file.path;
}