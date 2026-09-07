import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mood_sphere_painter.dart';

/// Combina el color (via [MoodSpherePainter]) con el brillo tipo vidrio,
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
class MoodSphereVisual extends StatelessWidget {
  final List<Color> colorsTopToBottom;
  final double size;

  /// Si es `false`, se omite el efecto glass (brillos, arcos tipo media
  /// luna con blur) y se usa el painter en modo simple. Pensado para las
  /// miniaturas del calendario, donde esos efectos son caros y apenas
  /// cambian la percepción.
  final bool glassEffects;

  const MoodSphereVisual({
    super.key,
    required this.colorsTopToBottom,
    required this.size,
    this.glassEffects = true,
  });

  @override
  Widget build(BuildContext context) {
    final canvasSize = Size(size, size);
    // RepaintBoundary aísla el pintado: si un ancestro se mueve (p. ej. la
    // flotación de la burbuja en MoodBubble), el compositor reutiliza la
    // capa ya rasterizada en vez de re-pintar gradientes y blurs cada frame.
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Stack(
            children: [
              // Color base: manchas de tinta difuminadas que se mezclan.
              Positioned.fill(
                child: CustomPaint(
                  painter: MoodSpherePainter(
                    colorsTopToBottom: colorsTopToBottom,
                    simple: !glassEffects,
                  ),
                ),
              ),

              if (glassEffects) ...[
                // Brillo principal: un blob grande y suave, arriba a la
                // izquierda. El propio degradado ya es suave, sin necesidad
                // de blur adicional. Se mantiene sutil para no lavar los
                // colores de abajo.
                Positioned(
                  top: -size * 0.05,
                  left: -size * 0.05,
                  width: size * 0.7,
                  height: size * 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),

                // Brillo secundario en la parte inferior derecha: espejo
                // diagonal del brillo superior izquierda, con el mismo
                // tamaño e intensidad para compensar la luz de la burbuja.
                Positioned(
                  right: -size * 0.05,
                  bottom: -size * 0.05,
                  width: size * 0.7,
                  height: size * 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),

                // Reflejo superior en forma de arco (media luna), el look
                // clásico de una burbuja de vidrio. Se desplaza hacia el
                // interior (no pegado al borde) para que respire.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrescentPainter(
                      rect: Rect.fromLTWH(
                        canvasSize.width * 0.17,
                        canvasSize.height * 0.13,
                        canvasSize.width * 0.5,
                        canvasSize.height * 0.5,
                      ),
                      startAngle: 3.6,
                      sweepAngle: 1.7,
                    ),
                  ),
                ),

                // Reflejo inferior derecho: espejo del arco superior, con
                // tamaño y posición acordes a la burbuja, para equilibrar
                // la luz en la esquina opuesta.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrescentPainter(
                      rect: Rect.fromLTWH(
                        canvasSize.width * 0.33,
                        canvasSize.height * 0.37,
                        canvasSize.width * 0.5,
                        canvasSize.height * 0.5,
                      ),
                      startAngle: 6.74,
                      sweepAngle: 1.7,
                      opacity: 0.45,
                    ),
                  ),
                ),
              ],

              // Borde translúcido para reforzar el contorno de burbuja,
              // más luminoso arriba que abajo (trazo, no relleno).
              Positioned.fill(
                child: CustomPaint(painter: _RimBorderPainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dibuja un trazo circular translúcido, más luminoso arriba que abajo,
/// para reforzar el contorno de burbuja.
class _RimBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final strokeWidth = size.width * 0.018;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.08)],
      ).createShader(rect);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - strokeWidth / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RimBorderPainter oldDelegate) => false;
}

/// Dibuja un reflejo tipo "media luna" que simula el vidrio de una burbuja:
/// una lente con las puntas afinadas, el grosor máximo en la mitad del arco
/// y caída suave, en vez de una línea uniforme. Configurable para colocarlo
/// en cualquier zona y orientación de la esfera ([rect], [startAngle],
/// [sweepAngle]).
class _CrescentPainter extends CustomPainter {
  final Rect rect;
  final double startAngle;
  final double sweepAngle;
  final double opacity;

  const _CrescentPainter({
    required this.rect,
    required this.startAngle,
    required this.sweepAngle,
    this.opacity = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Lente entre dos arcos: el arco interior usa un centro desplazado
    // hacia la dirección media y un barrido un poco más corto, de modo que
    // el grosor crece hacia la mitad del arco y se afina hasta morir en
    // los extremos. Tres lentes anidadas (halo difuso, cuerpo y núcleo
    // brillante) dan un reflejo orgánico con costo vectorial (nada de
    // `MaskFilter.blur` ni `ImageFiltered`).
    final c = rect.center;
    final r = rect.shortestSide / 2;
    final mid = startAngle + sweepAngle / 2;
    final dir = Offset(math.cos(mid), math.sin(mid));
    final eps = sweepAngle * 0.14;

    final lenses = [
      (thickness: 2.1, alpha: 0.10),
      (thickness: 1.0, alpha: 0.32),
      (thickness: 0.5, alpha: 0.55),
    ];

    final outerRect = Rect.fromCircle(center: c, radius: r);
    for (final lens in lenses) {
      final innerC = c + dir * (r * 0.26 * lens.thickness);
      final innerRect = Rect.fromCircle(center: innerC, radius: r);

      final path = Path()
        ..moveTo(
          c.dx + dirAt(startAngle).dx * r,
          c.dy + dirAt(startAngle).dy * r,
        )
        ..addArc(outerRect, startAngle, sweepAngle)
        ..lineTo(
          innerC.dx + dirAt(startAngle + sweepAngle - eps).dx * r,
          innerC.dy + dirAt(startAngle + sweepAngle - eps).dy * r,
        )
        ..addArc(innerRect, startAngle + sweepAngle - eps, -(sweepAngle - 2 * eps))
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: opacity * lens.alpha),
              Colors.white.withValues(alpha: opacity * lens.alpha * 0.35),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
      );
    }
  }

  Offset dirAt(double angle) => Offset(math.cos(angle), math.sin(angle));

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.opacity != opacity;
}
