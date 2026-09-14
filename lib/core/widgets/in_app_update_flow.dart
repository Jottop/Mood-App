import 'package:flutter/material.dart';

import '../../data/app_installer.dart';
import '../../data/app_update.dart';
import '../theme/app_colors.dart';
import 'app_snackbar.dart';

/// Botón "Descargar e instalar" unificado para el snackbar del home y el
/// dialog de ajustes: pide el permiso de instalación si falta, descarga con
/// progreso, verifica la integridad y abre el instalador nativo de Android.
/// Nunca abre el navegador ni la página hub.
Future<void> runInAppUpdate(BuildContext context, AppUpdateInfo update) async {
  // Snackbars con guarda de montaje: evita usar el context tras un await.
  void showMessage(String message) {
    if (!context.mounted) return;
    showAppSnackBar(context, content: Text(message));
  }

  const installer = AppInstaller();

  // 1) Permiso de instalación (Android 8+), antes de gastar la descarga.
  if (!await installer.canRequestInstalls()) {
    if (!context.mounted) return;
    final goToSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permitir instalar aplicaciones'),
        content: const Text(
          'Para que CamiMood se actualice por sí sola, Android necesita una '
          'vez tu permiso de "Permitir instalar aplicaciones desconocidas". '
          'Te abrimos esa pantalla; luego volvés y le das a Descargar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (goToSettings != true || !context.mounted) return;

    await installer.openInstallSettings();
    if (!await installer.canRequestInstalls()) {
      if (!context.mounted) return;
      showMessage(
        'Habilita "Permitir instalar aplicaciones desconocidas" para CamiMood '
        'y volvé a intentar la actualización.',
      );
      return;
    }
  }
  if (!context.mounted) return;

  // 2) Descarga con barra de progreso.
  final outcome = await showDialog<(String?, String?)>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadProgressDialog(update: update),
  );
  if (!context.mounted) return;

  final path = outcome?.$1;
  if (path == null) {
    showMessage(outcome?.$2 ?? 'No se pudo descargar la actualización.');
    return;
  }

  // 3) Instalación: Android abre su propio diálogo de confirmación (nativo).
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  try {
    await installer.launchInstaller(path);
  } catch (_) {
    if (!context.mounted) return;
    showMessage('No se pudo abrir el instalador. Reintenta.');
    return;
  }
  if (!context.mounted) return;
  showMessage(
    'Android te confirma la instalación. Tocá "Actualizar"; la app se cierra '
    'sola y queda la nueva versión.',
  );
}

/// Dialog de descarga con progreso: muestra la barra y el %, no permite
/// cerrarlo, y al terminar devuelve `(ruta, null)` o `(null, error)`.
class _DownloadProgressDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const _DownloadProgressDialog({required this.update});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double? _fraction;
  int _lastPct = -1;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final path = await downloadApk(
        widget.update,
        onProgress: (received, total, fraction) {
          final pct = (fraction * 100).round();
          if (pct == _lastPct) return;
          _lastPct = pct;
          if (!mounted) return;
          setState(() => _fraction = fraction);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop((path, null));
    } on UpdateDownloadException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop((null, e.message));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop((null, 'No se pudo descargar. Revisa tu conexión.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _fraction == null ? null : (_fraction! * 100).round();
    final size = formatAppSize(widget.update.sizeBytes);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Descargando v${widget.update.versionName}…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: _fraction,
              minHeight: 6,
              backgroundColor: AppColors.cardLine,
            ),
            const SizedBox(height: 12),
            Text(
              pct == null
                  ? 'Preparando${size.isEmpty ? '' : ' ($size)'}…'
                  : '$pct%${size.isEmpty ? '' : ' — $size'}',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}