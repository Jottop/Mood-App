import 'package:flutter/material.dart';

import '../../../core/widgets/special_badge.dart';
import '../../../data/models/mood_type.dart';

/// Selector rápido en grilla: 4 columnas, máximo 2 filas visibles. Si el
/// catálogo tiene más estados de los que caben, se puede hacer scroll
/// vertical dentro de la grilla para ver el resto.
///
/// Tocar un estado lo registra al instante, sin pasos intermedios (spec
/// §5: "el proceso debe ser rápido y requerir la menor cantidad de pasos
/// posible").
class MoodPickerGrid extends StatelessWidget {
  final List<MoodType> moods;
  final void Function(String moodId) onSelect;

  /// Cuántas veces está registrada cada emoción en el día que se está
  /// editando (`moodId -> cantidad`). Si una emoción no está en el mapa,
  /// su chip no muestra contador.
  final Map<String, int> moodsCount;

  static const _crossAxisCount = 4;
  static const _visibleRows = 2;
  static const _spacing = 8.0;
  // width / height de cada celda. 1.0 = celda cuadrada, suficiente para
  // el círculo grande con el color real.
  static const _aspectRatio = 1.0;

  const MoodPickerGrid({
    super.key,
    required this.moods,
    required this.onSelect,
    this.moodsCount = const {},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // El alto real de cada celda depende del ancho disponible (el
        // GridView lo calcula a partir de childAspectRatio), así que lo
        // medimos acá para que el contenedor tenga exactamente el alto
        // de 2 filas — nunca más, nunca menos.
        final totalWidth = constraints.maxWidth;
        final cellWidth = (totalWidth - _spacing * (_crossAxisCount - 1)) / _crossAxisCount;
        final cellHeight = cellWidth / _aspectRatio;
        final visibleHeight = cellHeight * _visibleRows + _spacing * (_visibleRows - 1);

        return SizedBox(
          height: visibleHeight,
          child: GridView.builder(
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
              childAspectRatio: _aspectRatio,
            ),
            itemCount: moods.length,
            itemBuilder: (context, index) {
              final mood = moods[index];
              return _MoodChip(
                emoji: mood.emoji,
                label: mood.label,
                color: mood.color,
                isSpecial: mood.isSpecial,
                count: moodsCount[mood.id] ?? 0,
                onTap: () => onSelect(mood.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _MoodChip extends StatefulWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool isSpecial;
  final int count;
  final VoidCallback onTap;

  const _MoodChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.isSpecial,
    required this.count,
    required this.onTap,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.16, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Círculo con el color real del estado (el emoji va dentro), y la
    // tarjeta que lo contiene con un fondo pálido para contrastar.
    final cardBg = Color.lerp(widget.color, Colors.white, 0.72)!;
    final iconBg = widget.color;
    final labelColor = Color.lerp(widget.color, Colors.black, 0.45)!;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 19)),
                  ),
                  // Insignia con la cantidad de veces que esta emoción ya
                  // está registrada en el día. Va sobre el círculo, dentro
                  // de la tarjeta, para no desbordar la celda.
                  if (widget.count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.count}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color.lerp(widget.color, Colors.black, 0.62),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: labelColor),
                    ),
                  ),
                  if (widget.isSpecial) ...[
                    const SizedBox(width: 2),
                    const SpecialBadge(size: 11),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
