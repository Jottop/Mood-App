import 'package:flutter/material.dart';

import '../../features/moods/widgets/custom_color_picker.dart';
import '../theme/app_colors.dart';

/// Fila de color con swatches preseleccionados + botón de color personalizado.
/// La usan Editar perfil y la configuración del widget del escritorio para que
/// ambos ofrezcan exactamente las mismas opciones (presets + color libre).
class ColorRow extends StatelessWidget {
  final String label;
  final Color? current;
  final List<Color> presets;
  final ValueChanged<Color> onPick;

  const ColorRow({
    super.key,
    required this.label,
    required this.current,
    required this.presets,
    required this.onPick,
  });

  Future<void> _openCustom(BuildContext context) async {
    final color = await showCustomColorPicker(
      context,
      initialColor: current ?? AppColors.bgTop,
    );
    if (color != null) onPick(color);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final color in presets)
              GestureDetector(
                onTap: () => onPick(color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current != null &&
                              current!.toARGB32() == color.toARGB32()
                          ? AppColors.ink
                          : AppColors.cardLine,
                      width: current != null &&
                              current!.toARGB32() == color.toARGB32()
                          ? 2.5
                          : 1,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openCustom(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardLine),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 20, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}