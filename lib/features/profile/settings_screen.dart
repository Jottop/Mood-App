import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/in_app_update_flow.dart';
import '../../data/app_update.dart';
import '../../state/auth_provider.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../widget_comparison/widget_comparison_screen.dart';
import 'edit_profile_screen.dart';

/// Pantalla de ajustes (se abre desde la "tuerca" del home): editar el perfil
/// (alias, avatar, colores de la píldora o credenciales), configurar e
/// instalar el widget de comparación, buscar actualizaciones por el hub y
/// cerrar la sesión.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Ajustes',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 80),
          children: [
            _OptionTile(
              icon: Icons.person_outline_rounded,
              title: 'Editar perfil',
              subtitle: 'Alias, avatar, colores de tu píldora, usuario y contraseña.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.widgets_outlined,
              title: 'Agregar widget',
              subtitle: 'Compara tu burbuja de hoy con la de un amigo en el escritorio.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WidgetComparisonScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.system_update_alt_rounded,
              title: 'Buscar actualizaciones',
              subtitle: 'Revisa si hay una versión más reciente y actualiza desde la app.',
              onTap: () => _checkForUpdates(context),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.logout_rounded,
              title: 'Cerrar sesión',
              subtitle: 'Tus registros quedan en tu cuenta; vuelve a entrar con tu usuario.',
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Chequeo manual: dialog con las notas y botón de descarga si hay versión
  /// nueva, snackbar si estás al día.
  Future<void> _checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Buscando actualizaciones…')));

    final update = await const AppUpdateService().fetchLatest();
    if (!context.mounted) return;
    if (update == null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo verificar. Revisa tu conexión.')),
      );
      return;
    }

    final installed = await AppUpdateService.installedVersionCode();
    if (!context.mounted) return;
    if (update.versionCode <= installed) {
      final version = await AppUpdateService.installedVersionName();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Estás al día (v$version).')));
      return;
    }

    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    final screenContext = context;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nueva versión v${update.versionName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (update.notes.isNotEmpty) ...[
                const Text('Novedades:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final note in update.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $note'),
                  ),
                const SizedBox(height: 8),
              ],
              Text(
                'Descargas ${formatAppSize(update.sizeBytes)} e instalás aquí mismo, sin salir de la app.',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              runInAppUpdate(screenContext, update);
            },
            child: const Text('Descargar e instalar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Cierra la sesión con confirmación explícita: forzamos el guardado
  /// pendiente de moods y catálogo antes de desloguear el dispositivo.
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tus registros y emociones quedan guardados en tu cuenta. Solo tendrás que volver a iniciar sesión con tu usuario y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final mood = context.read<MoodProvider>();
    final catalog = context.read<MoodCatalogProvider>();
    final auth = context.read<AuthProvider>();
    await mood.flushNow();
    await catalog.flushNow();
    await auth.signOut();
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.creamInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}