import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL del manifiesto de versiones que sirve la página hub (GitHub Pages).
/// Se puede sobreescribir al buildear con
/// `--dart-define=UPDATE_MANIFEST_URL=...`.
const String kUpdateManifestUrl = String.fromEnvironment(
  'UPDATE_MANIFEST_URL',
  defaultValue: 'https://jottop.github.io/Mood-App/manifest.json',
);

/// Unica versión publicada en la página hub, tal como la describen
/// `docs/manifest.json`.
class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final DateTime releaseDate;
  final List<String> notes;
  final int sizeBytes;
  final String sha256;
  final String apkUrl;

  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.releaseDate,
    required this.notes,
    required this.sizeBytes,
    required this.sha256,
    required this.apkUrl,
  });

  /// Parsea el manifiesto; devuelve `null` si el JSON está mal formado o le
  /// faltan campos obligatorios (el cliente de la app lo tolera y se queda
  /// sin avisar).
  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    final versionName = json['versionName'] as String?;
    final versionCode = json['versionCode'] as num?;
    final apkUrl = json['apkUrl'] as String?;
    if (versionName == null || versionCode == null || apkUrl == null) {
      return null;
    }
    return AppUpdateInfo(
      versionName: versionName,
      versionCode: versionCode.toInt(),
      releaseDate:
          DateTime.tryParse(json['releaseDate'] as String? ?? '') ?? DateTime(1970),
      notes: (json['notes'] as List<dynamic>? ?? const []).cast<String>(),
      sizeBytes: (json['sizeBytes'] as num? ?? 0).toInt(),
      sha256: json['sha256'] as String? ?? '',
      apkUrl: apkUrl,
    );
  }
}

/// Consulta el manifiesto del hub y compara contra la instalación local.
class AppUpdateService {
  const AppUpdateService();

  /// Última versión publicada según el hub, o `null` si no se pudo leer.
  Future<AppUpdateInfo?> fetchLatest() async {
    try {
      final response = await http
          .get(Uri.parse(kUpdateManifestUrl))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AppUpdateInfo.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Versión instalada, desde el metadata del paquete.
  static Future<String> installedVersionName() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// versionCode instalado; `0` si no se pudo leer.
  static Future<int> installedVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }
}

/// Abre el .apk en el navegador; Chrome descarga y dispara el instalador.
/// Compartido entre el chequeo automático del home y el manual de ajustes.
Future<void> launchAppDownload(AppUpdateInfo update) async {
  await launchUrl(Uri.parse(update.apkUrl), mode: LaunchMode.externalApplication);
}

/// Formatea el tamaño del .apk a "X.X MB" (vacío si viene en 0).
String formatAppSize(int bytes) {
  if (bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}