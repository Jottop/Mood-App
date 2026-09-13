import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widget_comparison/widget_comparison_screen.dart';
import 'edit_profile_screen.dart';

/// Pantalla de ajustes (se abre desde la "tuerca" del home): editar el perfil
/// (alias, avatar, colores de la píldora o credenciales) y configurar e
/// instalar el widget de comparación.
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
          ],
        ),
      ),
    );
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