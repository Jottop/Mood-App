import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/mood_type.dart';
import '../../state/mood_catalog_provider.dart';
import 'mood_editor_screen.dart';

/// Lista de estados de ánimo del catálogo, con opción de editar cada uno
/// o agregar uno nuevo (spec §1: agregar, modificar o eliminar estados).
class ManageMoodsScreen extends StatelessWidget {
  const ManageMoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Mis estados de ánimo', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Consumer<MoodCatalogProvider>(
        builder: (context, catalog, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            children: [
              for (final mood in catalog.moods) ...[
                _MoodRow(mood: mood),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar estado'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MoodEditorScreen()),
        ),
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  final MoodType mood;
  const _MoodRow({required this.mood});

  @override
  Widget build(BuildContext context) {
    // Mismo patrón que los chips del selector: círculo con el color real
    // del estado y la tarjeta (más grande) con un fondo pálido.
    final cardBg = Color.lerp(mood.color, Colors.white, 0.78)!;
    final iconBg = mood.color;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MoodEditorScreen(existing: mood)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Text(mood.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  mood.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
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
