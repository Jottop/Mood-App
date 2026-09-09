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
class MoodBubble extends StatelessWidget {
  /// Colores de los registros de hoy, en orden cronológico (de más
  /// antiguo a más reciente). Vacío = todavía no hay registros hoy.
  final List<Color> todayColors;
  final String label;

  /// Colores de las emociones especiales presentes hoy (para el aura).
  final List<Color> specialColors;

  const MoodBubble({
    super.key,
    required this.todayColors,
    required this.label,
    this.specialColors = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingSphere(
          // Más reciente arriba, para que coincida con el texto debajo
          // ("ahora te sientes...").
          colors: todayColors.reversed.toList(),
          auraColors: specialColors,
          size: 220,
        ),
        const SizedBox(height: 16),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 14.5),
        ),
      ],
    );
  }
}

/// La esfera con las animaciones de la burbuja principal: flotación
/// continua (sube y baja suavemente) y, cuando cambia el contenido,
/// transición de fundido + rebote.
///
/// Compartida entre la burbuja del Home y el detalle de un día para que
/// ambas se vean igual.
class FloatingSphere extends StatefulWidget {
  /// Colores de más reciente (arriba) a más antiguo (abajo). Vacío =
  /// esfera "vacía".
  final List<Color> colors;

  /// Colores de las emociones especiales presentes (para el aura).
  final List<Color> auraColors;
  final double size;

  /// Cuántos píxeles sube/baja la flotación.
  final double floatAmplitude;

  const FloatingSphere({
    super.key,
    required this.colors,
    this.auraColors = const [],
    this.size = 220,
    this.floatAmplitude = 14,
  });

  @override
  State<FloatingSphere> createState() => _FloatingSphereState();
}

class _FloatingSphereState extends State<FloatingSphere>
    with SingleTickerProviderStateMixin {
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
    final key = ValueKey(widget.colors.map((c) => c.toARGB32()).join('-'));

    // El aura dibuja anillos concéntricos por fuera del borde (sin clipado).
    // El espacio reservado arriba/abajo es FIJO (no depende de cuántos
    // anillos haya) para que el layout no salte al agregar emociones.
    final auraPad = MoodSphereVisual.auraReservedSpace(widget.size);

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = (Curves.easeInOut.transform(_floatController.value) - 0.5) * widget.floatAmplitude;
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
        child: Padding(
          key: key,
          padding: EdgeInsets.symmetric(vertical: auraPad),
          child: MoodSphereVisual(
            colorsTopToBottom: widget.colors,
            size: widget.size,
            auraColors: widget.auraColors,
          ),
        ),
      ),
    );
  }
}
