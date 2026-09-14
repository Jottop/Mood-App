import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/emoji_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/special_badge.dart';
import '../../data/models/mood_type.dart';
import '../../state/mood_catalog_provider.dart';
import 'mood_editor_screen.dart';
import 'trash_screen.dart';

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
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
            tooltip: 'Papelera',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.inkSoft),
          ),
        ],
      ),
      body: Consumer<MoodCatalogProvider>(
        builder: (context, catalog, _) {
          // Una sola lectura: el getter copia la lista (O(N)), así que no
          // conviene llamarlo por fila dentro de itemBuilder mientras el
          // arrastre reconstruye las filas animadas.
          final moods = catalog.moods;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.inkSoft),
                    SizedBox(width: 6),
                    Text(
                      'Mantén presionado para reordenar',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 170),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: RepaintBoundary(
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.03).animate(animation),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  itemCount: moods.length,
                  onReorderItem: (oldIndex, newIndex) => catalog.reorderMoods(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final mood = moods[index];
                    return Padding(
                      key: ValueKey(mood.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RepaintBoundary(
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: _MoodRow(mood: mood),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // La píldora del hub de amigos flota centrada sobre el borde inferior de
      // TODAS las pantallas, así que el botón sube (margen dinámico calculado
      // por [fabReserveFor]) para nunca quedar tapado ni rozarla; el Builder se
      // re-construye solo cuando la píldora se mueve. El margen mínimo alto
      // (126) deja además el aviso de "Deshacer", que ahora va pegado abajo,
      // sin que el botón lo tape.
      floatingActionButton: Builder(
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: fabReserveFor(context, minimum: 126)),
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar estado'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MoodEditorScreen()),
            ),
          ),
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
                child: Text(mood.emoji,
                  style: const TextStyle(fontSize: 24, fontFamilyFallback: kEmojiFontFallback)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        mood.label,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                    if (mood.isSpecial) ...[
                      const SizedBox(width: 6),
                      const SpecialBadge(),
                    ],
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
