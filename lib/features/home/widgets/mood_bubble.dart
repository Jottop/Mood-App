import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'mood_sphere_visual.dart';

/// La burbuja visual principal (spec §4).
///
/// Pinta la esfera con manchas de color difuminadas para cada estado de
/// hoy: la más antigua es la más grande (fuerte arriba, desvaneciéndose
/// hacia abajo) y cada estado nuevo agrega una mancha más chica encima,
/// mezclándose con las anteriores sin dividir la esfera en secciones.
/// Al agregar un nuevo registro, hace una transición suave (fundido + un
/// pequeño rebote) en vez de un cambio brusco.
class MoodBubble extends StatefulWidget {
  /// Colores de los registros de hoy, en orden cronológico (de más
  /// antiguo a más reciente). Vacío = todavía no hay registros hoy.
  final List<Color> todayColors;
  final String label;

  const MoodBubble({super.key, required this.todayColors, required this.label});

  @override
  State<MoodBubble> createState() => _MoodBubbleState();
}

class _MoodBubbleState extends State<MoodBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clave estable derivada de los colores actuales: cuando cambia,
    // AnimatedSwitcher hace la transición entre la esfera vieja y la nueva.
    final key = ValueKey(widget.todayColors.map((c) => c.toARGB32()).join('-'));

    return Column(
      children: [
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final floatOffset =
                (Curves.easeInOut.transform(_floatController.value) - 0.5) * 14;
            return Transform.translate(offset: Offset(0, floatOffset), child: child);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 650),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                child: child,
              ),
            ),
            // Más reciente arriba, para que coincida con el texto debajo
            // ("ahora te sientes...").
            child: _Sphere(key: key, colors: widget.todayColors.reversed.toList()),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 14.5),
        ),
      ],
    );
  }
}

class _Sphere extends StatelessWidget {
  final List<Color> colors;
  const _Sphere({super.key, required this.colors});

  static const double _size = 220;

  @override
  Widget build(BuildContext context) {
    return MoodSphereVisual(
      colorsTopToBottom: colors,
      size: _size,
    );
  }
}
