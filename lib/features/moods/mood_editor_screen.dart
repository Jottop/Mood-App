import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mood_catalog.dart';
import '../../data/models/mood_type.dart';
import '../../state/mood_catalog_provider.dart';
import 'widgets/custom_color_picker.dart';

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
  late final TextEditingController _emojiController;
  late Color _selectedColor;
  late bool _isSpecial;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label ?? '');
    _emojiController = TextEditingController(text: widget.existing?.emoji ?? '');
    _selectedColor = widget.existing?.color ?? MoodColorPalette.options.first;
    _isSpecial = widget.existing?.isSpecial ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  bool get _isValid => _labelController.text.trim().isNotEmpty && _emojiController.text.trim().isNotEmpty;

  /// `true` si el color actual no pertenece a la paleta rápida (cuando el
  /// usuario eligió un color personalizado).
  bool get _isCustomColorSelected =>
      !MoodColorPalette.options.any((c) => c.toARGB32() == _selectedColor.toARGB32());

  Future<void> _openCustomColorPicker() async {
    final color = await showCustomColorPicker(context, initialColor: _selectedColor);
    if (color != null && mounted) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _save() async {
    final catalog = context.read<MoodCatalogProvider>();
    final label = _labelController.text.trim();
    final emoji = _emojiController.text.trim();

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
      await context.read<MoodCatalogProvider>().deleteMood(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Vista previa en vivo.
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_labelController, _emojiController]),
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
                              _emojiController.text.isEmpty ? '🙂' : _emojiController.text,
                              style: const TextStyle(fontSize: 28),
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
          TextField(
            controller: _emojiController,
            maxLength: 2,
            decoration: InputDecoration(
              hintText: 'Toca y usa el teclado de emojis de tu teléfono',
              filled: true,
              fillColor: AppColors.card,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in MoodColorPalette.options)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
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
                selected: _isCustomColorSelected,
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
