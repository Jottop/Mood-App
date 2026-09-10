import 'package:flutter/material.dart';

import '../../../core/widgets/mood_sphere_painters.dart';

/// Combina el color (via `MoodSpherePainter`) con el brillo tipo vidrio,
/// escalado según [size]. Se usa tanto en la burbuja principal (grande)
/// como en las miniaturas del calendario (chicas), para que ambas se
/// vean consistentes.
///
/// IMPORTANTE: acá nunca se usa `ImageFiltered`/`ImageFilter.blur` sobre
/// el árbol de widgets, porque desenfocar una capa con zonas
/// transparentes puede "filtrar" negro desde esos píxeles (un problema
/// conocido de Flutter/Skia con alpha premultiplicado) — eso era lo que
/// causaba el fondo negro en la burbuja vacía. Todo el difuminado se
/// logra con degradados y `Paint.maskFilter` dentro de un CustomPainter,
/// que sí son seguros sobre fondos transparentes.
///
/// El dibujo completo (base + vidrio + borde + aura) vive en
/// [MoodSphereVisualPainter], que también se puede invocar offscreen para
/// rasterizar la burbuja exacta fuera del árbol de widgets (p. ej. el
/// widget del escritorio de comparación).
class MoodSphereVisual extends StatelessWidget {
  final List<Color> colorsTopToBottom;
  final double size;

  /// Si es `false`, se omite el efecto glass (brillos, arcos tipo media
  /// luna con blur) y se usa el painter en modo simple. Pensado para las
  /// miniaturas del calendario, donde esos efectos son caros y apenas
  /// cambian la percepción.
  final bool glassEffects;

  /// Modo compacto para miniaturas (calendario): una sola media luna
  /// nítida (sin `MaskFilter.blur`), el blob superior y el painter simple.
  /// Mantiene la lectura de "vidrio" con un costo mínimo: los blur son la
  /// parte más cara al haber muchas burbujas en pantalla.
  final bool compact;

  /// Colores de las emociones "especiales" presentes. Si no está vacío, se
  /// dibujan anillos concéntricos de neón alrededor de la burbuja, uno por
  /// cada emoción distinta (en orden de primera aparición, cada uno más
  /// grande que el anterior). Vacío = sin aura (cero costo). Se
  /// deduplican internamente; repetir una misma especial no agrega un
  /// anillo ni lo intensifica.
  final List<Color> auraColors;

  const MoodSphereVisual({
    super.key,
    required this.colorsTopToBottom,
    required this.size,
    this.glassEffects = true,
    this.compact = false,
    this.auraColors = const [],
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary aísla el pintado: si un ancestro se mueve (p. ej. la
    // flotación de la burbuja en MoodBubble), el compositor reutiliza la
    // capa ya rasterizada en vez de re-pintar gradientes y blurs cada frame.
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: MoodSphereVisualPainter(
            colorsTopToBottom: colorsTopToBottom,
            glassEffects: glassEffects,
            compact: compact,
            auraColors: auraColors,
          ),
        ),
      ),
    );
  }

  /// Espacio fijo (en píxeles) que se reserva arriba y abajo de la burbuja
  /// para el aura, tanto si hay 0 como 6 anillos. Cubre hasta
  /// [kReservedAuraRings]; si se supera, los anillos extras apenas se
  /// superponen (caso improbable).
  static double auraReservedSpace(double size) =>
      size * (kAuraRingStep * kReservedAuraRings + kAuraBlurMargin);
}