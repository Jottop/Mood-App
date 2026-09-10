import 'package:flutter/material.dart';

import '../../../core/emoji_pack.dart';
import '../../../core/theme/app_colors.dart';

/// Selector de emoji del pack curado (ver [EmojiPack]).
///
/// Reemplaza al teclado de emojis del teléfono: cada opción es un círculo
/// claro (mismo lenguaje visual que los avatares del hub de amigos) y la
/// seleccionada lleva un anillo oscuro. Al no dejar escribir emojis a mano,
/// nada que no exista en el pack puede guardarse.
class EmojiPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const EmojiPicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in EmojiPack.categories) ...[
          Text(
            category.label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final emoji in category.emojis)
                EmojiOption(
                  emoji: emoji,
                  isSelected: emoji == selected,
                  onTap: () => onSelect(emoji),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class EmojiOption extends StatelessWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const EmojiOption({super.key, required this.emoji, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Emoji',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cream : AppColors.card,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: AppColors.ink, width: 2)
                : Border.all(color: AppColors.cardLine, width: 1),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 20, fontFamilyFallback: kEmojiFontFallback),
          ),
        ),
      ),
    );
  }
}

/// Submenú modal que muestra el [EmojiPicker] con scroll. Al tocar un emoji
/// cierra la hoja devolviéndolo (`Navigator.pop`).
class EmojiPickerSheet extends StatelessWidget {
  final String selected;

  const EmojiPickerSheet({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        child: ListView(
          shrinkWrap: true,
          // Margen inferior generoso: la píldora flotante de amigos tapa el
          // final de la hoja si no dejamos espacio reservado.
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 84),
          children: [
            const Center(
              child: Text(
                'Elige un emoji',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 16),
            EmojiPicker(
              selected: selected,
              onSelect: (emoji) => Navigator.of(context).pop(emoji),
            ),
          ],
        ),
      ),
    );
  }
}