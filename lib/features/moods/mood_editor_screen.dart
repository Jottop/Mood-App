import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/emoji_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/undo_progress_bar.dart';
import '../../data/mood_catalog.dart';
import '../../data/models/mood_type.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_color_palette_provider.dart';
import 'widgets/custom_color_picker.dart';
import 'widgets/emoji_picker.dart';

/// Formulario para crear un estado de ánimo nuevo, o editar/eliminar uno
/// existente si se pasa [existing] (spec §1).
class MoodEditorScreen extends StatefulWidget {
  final MoodType? existing;
  const MoodEditorScreen({super.key, this.existing});

  @override
  State<MoodEditorScreen> createState() => _MoodEditorScreenState();
}

class _MoodEditorScreenState extends State<MoodEditorScreen> {
  late final TextEditingController _labelController;
  // Emoji elegido del pack curado. Arranca con el emoji existente
  // saneado (o el neutro del pack si es un estado nuevo).
  late String _selectedEmoji;
  late Color _selectedColor;
  late bool _isSpecial;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label ?? '');
    _selectedEmoji = EmojiPack.sanitize(widget.existing?.emoji);
    _selectedColor = widget.existing?.color ?? MoodColorPalette.options.first;
    _isSpecial = widget.existing?.isSpecial ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  bool get _isValid => _labelController.text.trim().isNotEmpty && _selectedEmoji.isNotEmpty;

  /// `true` si el color actual no pertenece a la paleta visible (cuando el
  /// usuario eligió un color personalizado aún no guardado o fuera de
  /// [MoodColorPaletteProvider.all]).
  bool _isCustomColorSelected(List<Color> palette) =>
      !palette.any((c) => c.toARGB32() == _selectedColor.toARGB32());

  Future<void> _openCustomColorPicker() async {
    final color = await showCustomColorPicker(context, initialColor: _selectedColor);
    if (color != null && mounted) {
      // El color elegido queda guardado entre los colores elegibles: pasa
      // a aparecer como opción rápida (swatch) la próxima vez que se abra
      // el editor, sin volver a recorrer el selector libre.
      context.read<MoodColorPaletteProvider>().addCustom(color);
      setState(() => _selectedColor = color);
    }
  }

  /// Diálogo de confirmación para quitar un color de la paleta (se dispara
  /// con mantener presionado sobre el swatch).
  Future<void> _confirmRemoveColor(Color color) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar color'),
        content: const Text(
          '¿Quieres dejar de mostrar este color en la paleta? Puedes usar "Restaurar originales" si te arrepientes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<MoodColorPaletteProvider>().removeColor(color);
    }
  }

  /// Diálogo de confirmación para restaurar la paleta de colores originales
  /// por defecto (elimina personalizados y devuelve los base ocultos).
  Future<void> _confirmRestorePalette() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar colores originales'),
        content: const Text(
          'Se eliminarán tus colores personalizados y volverán los colores por defecto que quitaste. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<MoodColorPaletteProvider>().restoreDefault();
    }
  }

  /// Abre el submenú del selector de emojis; al elegir uno, actualiza el
  /// estado seleccionado.
  Future<void> _openEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgBottom,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => EmojiPickerSheet(selected: _selectedEmoji),
    );
    if (emoji != null && mounted) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  Future<void> _save() async {
    final catalog = context.read<MoodCatalogProvider>();
    final label = _labelController.text.trim();
    final emoji = _selectedEmoji;

    if (_isEditing) {
      await catalog.updateMood(
        widget.existing!.id,
        label: label,
        emoji: emoji,
        color: _selectedColor,
        isSpecial: _isSpecial,
      );
    } else {
      // Límite óptimo de 10 emociones: se advierte, pero se permite agregar
      // de todas formas si el usuario lo confirma (spec §1).
      if (catalog.moods.length >= MoodCatalogProvider.maxOptimalMoods) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Límite alcanzado'),
            content: const Text(
              'Ya tienes 10 emociones, que es el máximo óptimo para un uso fluido del selector. ¿Deseas agregarla de todas formas?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Agregar de todas formas'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
      await catalog.addMood(label: label, emoji: emoji, color: _selectedColor, isSpecial: _isSpecial);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este estado?'),
        content: const Text(
          'Los registros que ya tengas guardados con este estado se conservan, pero dejará de aparecer en el selector.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final catalog = context.read<MoodCatalogProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final moodId = widget.existing!.id;
      // Se captura antes del await/pop: el context del editor queda
      // desmontado al volver a la lista.
      final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
      await catalog.deleteMood(moodId);
      if (mounted) Navigator.of(context).pop();
      // La barra drena en 4s y al terminar cierra el aviso: es lo que
      // garantiza que desaparezca, porque un SnackBar con "Deshacer" no se
      // cierra solo (mismo patrón que en las listas de registros del día).
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            // El FAB "Agregar estado" está elevado sobre la píldora de
            // amigos (96) y mide ~56: el aviso se eleva para no tapar el
            // botón ni quedar detrás de la píldora.
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 164),
            // Barra clara (no opaca) para que no tape la lista de debajo.
            backgroundColor: AppColors.card,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardLine),
            ),
            content: UndoProgressBar(
              duration: const Duration(seconds: 4),
              // Al terminar la barra se cierra el aviso: desaparición a
              // los 4s garantizada.
              onFinished: () => messenger.hideCurrentSnackBar(),
              label: 'Emoción eliminada',
            ),
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: AppColors.ink,
              onPressed: () => catalog.restoreMood(moodId),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paleta visible = colores curados (menos los ocultos) + personalizados
    // guardados. El provider se observa para reflejar altas/bajas al toque.
    final paletteProvider = context.watch<MoodColorPaletteProvider>();
    final palette = paletteProvider.all;
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: Text(
          _isEditing ? 'Editar estado' : 'Nuevo estado',
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          // Vista previa en vivo.
          Center(
            child: AnimatedBuilder(
              animation: _labelController,
              builder: (context, _) {
                // Mismo patrón del selector: tarjeta pálida que contiene
                // el círculo con el color real y el emoji bien grande.
                final previewCardBg = Color.lerp(_selectedColor, Colors.white, 0.72)!;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: previewCardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 28, fontFamilyFallback: kEmojiFontFallback),
                            ),
                          ),
                          if (_isSpecial)
                            // Brillo sutil que anticipa el aura de la burbuja.
                            IgnorePointer(
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedColor.withValues(alpha: 0.55),
                                      blurRadius: 16,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _labelController.text.isEmpty ? 'Nombre del estado' : _labelController.text,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          const Text('Nombre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          TextField(
            controller: _labelController,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Ej: Motivado',
              filled: true,
              fillColor: AppColors.card,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          const Text('Emoji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          _EmojiPickerButton(selected: _selectedEmoji, onTap: _openEmojiPicker),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
              const Spacer(),
              // Restaura la paleta de fábrica: vuelve los colores base que
              // se ocultaron y elimina los personalizados guardados.
              if (paletteProvider.isModified)
                TextButton.icon(
                  onPressed: _confirmRestorePalette,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.inkSoft,
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restaurar originales'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in palette)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  // Mantener presionado permite quitar el color de la
                  // paleta (base o personalizado).
                  onLongPress: () => _confirmRemoveColor(color),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor.toARGB32() == color.toARGB32()
                          ? Border.all(color: AppColors.ink, width: 3)
                          : null,
                    ),
                  ),
                ),
              // Opcion de color personalizado al final de la fila.
              _CustomColorTile(
                selected: _isCustomColorSelected(palette),
                onTap: _openCustomColorPicker,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardLine),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emoción especial',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Se destacará con un aura alrededor de la burbuja',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _isSpecial,
                  activeTrackColor: _selectedColor,
                  onChanged: (v) => setState(() => _isSpecial = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isValid ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_isEditing ? 'Guardar cambios' : 'Agregar estado'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile al final de la paleta rápida: círculo pálido con "+" que abre el
/// selector de color personalizado.
class _CustomColorTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CustomColorTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.cardLine,
            width: selected ? 3 : 1,
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 22, color: AppColors.inkSoft),
      ),
    );
  }
}

/// Botón del campo "Emoji": muestra el emoji elegido y abre el submenú con
/// el [EmojiPickerSheet] al tocarlo.
class _EmojiPickerButton extends StatelessWidget {
  final String selected;
  final VoidCallback onTap;

  const _EmojiPickerButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
              child: Text(
                selected,
                style: const TextStyle(fontSize: 20, fontFamilyFallback: kEmojiFontFallback),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Elegir emoji',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
