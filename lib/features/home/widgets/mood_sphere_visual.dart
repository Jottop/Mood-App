import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mood_sphere_painter.dart';

/// Anillo del aura en la burbuja grande (fracción del widget): también es
/// el paso entre los centros de anillos consecutivos. Como el trazo usa ese
/// mismo ancho, los anillos son CONTIGUOS — el borde interno de cada uno
/// toca el borde externo del anterior y el primero pegado a la burbuja.
const double _auraRingStep = 0.032;

/// Grosor del blur del anillo (misma escala): bajo para que los anillos se
/// lean como bandas separadas, sin dar la sensación de que se mezclan.
/// También se suma al espacio fijo reservado para el resto del glow.
const double _auraBlurMargin = 0.008;

/// Calendario (compacto): los anillos van FINOS y con una separación leve
/// (el paso de centros es mayor que el grosor del trazo: `gap = step -
/// stroke`) para que se lean bien aunque la burbuja sea chica y no rompan
/// las celdas de ~40px.
const double _auraCompactStep = 0.036;
const double _auraCompactStroke = 0.016;

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
    final canvasSize = Size(size, size);
    // RepaintBoundary aísla el pintado: si un ancestro se mueve (p. ej. la
    // flotación de la burbuja en MoodBubble), el compositor reutiliza la
    // capa ya rasterizada en vez de re-pintar gradientes y blurs cada frame.
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          // El aura se dibuja por fuera del borde de la burbuja (que sí
          // queda recortado por ClipOval), así que el Stack no debe clipar
          // a sus propios límites.
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: Stack(
                children: [
              // Color base: manchas de tinta difuminadas que se mezclan.
              Positioned.fill(
                child: CustomPaint(
                  painter: MoodSpherePainter(
                    colorsTopToBottom: colorsTopToBottom,
                    simple: !glassEffects || compact,
                  ),
                ),
              ),

              if (glassEffects) ...[
                // Brillo principal: un blob grande y suave, arriba a la
                // izquierda. El propio degradado ya es suave, sin necesidad
                // de blur adicional. Se mantiene sutil para no lavar los
                // colores de abajo.
                Positioned(
                  top: -size * 0.1,
                  left: -size * 0.2,
                  width: size * 0.9,
                  height: size * 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.43),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),

                if (!compact)
                  // Brillo secundario en la parte inferior derecha: espejo
                  // diagonal del brillo superior izquierda, con el mismo
                  // tamaño e intensidad para compensar la luz de la burbuja.
                  Positioned(
                    right: -size * 0.16,
                    bottom: -size * 0.18,
                    width: size * 0.7,
                    height: size * 0.7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.58),
                            Colors.white.withValues(alpha: 0.07),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),

                // Reflejo superior en forma de arco (media luna), el look
                // clásico de una burbuja de vidrio. Concéntrico con la
                // burbuja (mismo centro) para que su curvatura siga el
                // borde; centrado arriba, subiendo desde la
                // izquierda-hacia-arriba hasta la derecha-hacia-arriba.
                // En modo compacto se dibuja nítido (sin blur).
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrescentPainter(
                      rect: Rect.fromCircle(
                        center: Offset(canvasSize.width * 0.46, canvasSize.height * 0.39),
                        radius: canvasSize.width * 0.25,
                      ),
                      startAngle: 3.3,
                      sweepAngle: 1.6,
                      // Superior: fino en la punta de arriba (fin del
                      // barrido) y grueso hacia el otro extremo.
                      tStart: canvasSize.width * 0.09,
                      tEnd: canvasSize.width * 0.02,
                      blur: !compact,
                    ),
                  ),
                ),

                // Reflejo inferior derecho: espejo del arco superior, con
                // tamaño y posición acordes a la burbuja, para equilibrar
                // la luz en la esquina opuesta. Solo en modo completo.
                if (!compact)
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
                        sweepAngle: 1.1,
                        opacity: 0.65,
                        // Inferior: al revés que el superior, empieza grueso
                        // y termina fino.
                        tStart: canvasSize.width * 0.048,
                        tEnd: canvasSize.width * 0.025,
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
            if (auraColors.isNotEmpty)
              // Aura tipo "neón" por fuera del borde: un anillo
              // concéntrico por cada emoción especial, cada uno más grande
              // que el anterior (el primero pegado a la burbuja, el último
              // el más externo). La burbuja grande lo difumina (halo
              // suave); el calendario usa anillos delgados sin blur, mucho
              // más baratos, para no romper el diseño de las celdas.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: compact
                        ? _AuraSimplePainter(colors: auraColors)
                        : _AuraPainter(colors: auraColors),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Cuántos anillos de aura reservar de antemano ARRIBA Y ABAJO de la
  /// burbuja en las burbujas grandes. El espacio es FIJO (no depende de
  /// cuántos anillos haya en este momento) para que el layout no "salte"
  /// cada vez que se agrega una emoción especial: la burbuja ya nace con
  /// este margen, listo para los anillos que lleguen.
  static const int reservedAuraRings = 6;

  /// Espacio fijo (en píxeles) que se reserva arriba y abajo de la burbuja
  /// para el aura, tanto si hay 0 como 6 anillos. Cubre hasta
  /// [reservedAuraRings]; si se supera, los anillos extras apenas se
  /// superponen (caso improbable).
  static double auraReservedSpace(double size) =>
      size * (_auraRingStep * reservedAuraRings + _auraBlurMargin);
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

/// Una capa del aura: una sola entrada por cada emoción especial distinta
/// registrada. Las repeticiones de la misma emoción NO agregan anillo ni
/// intensifican: la capa sale una única vez y siempre al mismo alpha.
typedef _AuraLayer = Color;

/// Devuelve los colores especiales ÚNICOS, en el ORDEN DE PRIMERA
/// APARICIÓN (la primera vez que cada emoción especial se registró). Con
/// eso el orden del aura es estable y legible: repetir una emoción que ya
/// estaba NO la reordena ni refuerza su anillo — solo aparece una vez, en
/// la posición donde entró por primera vez, siempre con la misma
/// intensidad.
List<_AuraLayer> _auraLayers(List<Color> colors) {
  if (colors.isEmpty) return const [];

  final seen = <int>{};
  return [
    for (final c in colors)
      if (seen.add(c.toARGB32())) c,
  ];
}

/// Aura tipo "neón" alrededor de la burbuja (Home / detalle del día):
/// anillos concéntricos que crecen hacia afuera — cada emoción especial
/// (color único, en orden de primera aparición) agrega UN anillo más
/// grande que el anterior. Los anillos son CONTIGUOS: el borde interno de
/// cada uno toca el borde externo del anterior, y el primero arranca
/// pegado a la burbuja (sin separación). El glow del blur de cada anillo
/// se funde suavemente hacia el siguiente (transición hacia el próximo
/// color) sin llegar a mezclar los colores.
///
/// Registrar varias veces la MISMA emoción no agrega nada: ni un anillo
/// nuevo, ni mayor intensidad — siempre un solo anillo al mismo alpha
/// (0.6), en la posición donde entró por primera vez.
class _AuraPainter extends CustomPainter {
  final List<Color> colors;
  const _AuraPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = _auraLayers(colors);
    if (layers.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;
    const alpha = 0.6;
    // El centro de cada anillo se corre `_auraRingStep` y el trazo usa ese
    // mismo ancho: así los anillos quedan contiguos, sin huecos entre ellos.
    final step = size.width * _auraRingStep;

    for (var i = 0; i < layers.length; i++) {
      final r = baseR + step * (i + 0.5);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * _auraRingStep
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * _auraBlurMargin);
      paint.color = layers[i].withValues(alpha: alpha);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i].toARGB32() != colors[i].toARGB32()) return true;
    }
    return false;
  }
}

/// Versión ultra barata del aura para las miniaturas del calendario: el
/// MISMO concepto de anillos concéntricos delgados (orden de primera
/// aparición), pero sin `MaskFilter.blur` — trazos muy finos y radios
/// ajustados para no romper el diseño de las celdas (~40px). Un
/// `drawCircle` por color, sin shaders; el `RepaintBoundary` cachea la
/// capa tras el primer pintado (incluso con ~37 burbujas a la vista).
/// Repetir una misma especial no cambia nada: un solo anillo al mismo
/// alpha.
class _AuraSimplePainter extends CustomPainter {
  final List<Color> colors;
  const _AuraSimplePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = _auraLayers(colors);
    if (layers.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;
    const alpha = 0.6;
    // Paso entre centros mayor que el grosor del trazo => separación leve
    // entre anillos (se leen bien en las miniaturas sin romper la celda).
    final step = size.width * _auraCompactStep;

    for (var i = 0; i < layers.length; i++) {
      final r = baseR + step * (i + 0.5);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * _auraCompactStroke;
      paint.color = layers[i].withValues(alpha: alpha);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraSimplePainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i].toARGB32() != colors[i].toARGB32()) return true;
    }
    return false;
  }
}

/// Dibuja un reflejo tipo "media luna" que simula el vidrio de una burbuja:
/// una cinta blanca cuyo grosor cambia a lo largo del arco, de [tStart]
/// (en [startAngle]) hasta [tEnd] (al final del barrido), con borde
/// difuminado por gaussiana — las puntas quedan suaves y ovaladas al
/// difuminar la máscara completa del relleno. Configurable para colocarlo
/// en cualquier zona y orientación de la esfera.
class _CrescentPainter extends CustomPainter {
  final Rect rect;
  final double startAngle;
  final double sweepAngle;
  final double opacity;

  /// Grosor (px) en [startAngle].
  final double tStart;

  /// Grosor (px) al final del barrido.
  final double tEnd;

  /// Si es `false` se omite el `MaskFilter.blur`: los bordes quedan
  /// nítidos. Para miniaturas, donde repintar muchos blurs es caro.
  final bool blur;

  const _CrescentPainter({
    required this.rect,
    required this.startAngle,
    required this.sweepAngle,
    this.opacity = 0.8,
    this.tStart = 18,
    this.tEnd = 58,
    this.blur = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Cinta con extremos circularmente cerrados, todo en un único path:
    // contorno exterior (arco), punta final (semicírculo geométrico),
    // contorno interior (muestreo con el grosor variable) y punta inicial
    // (semicírculo), cerrando en el punto inicial. Así las puntas son
    // verdaderas semicircunferencias de la propia figura, no círculos
    // pegados encima, y el `MaskFilter.blur` se aplica uniforme a toda la
    // silueta (borde difuminado, centro blanco plano).
    final c = rect.center;
    final r0 = rect.shortestSide / 2;
    final a0 = startAngle;
    final a1 = startAngle + sweepAngle;

    final capStartC = c + Offset(math.cos(a0), math.sin(a0)) * (r0 + tStart / 2);
    final capEndC = c + Offset(math.cos(a1), math.sin(a1)) * (r0 + tEnd / 2);

    final path = Path()
      ..moveTo(c.dx + math.cos(a0) * r0, c.dy + math.sin(a0) * r0)
      ..arcTo(Rect.fromCircle(center: c, radius: r0), a0, sweepAngle, false)
      // Punta final: semicírculo de radio tEnd/2 que protruye hacia
      // adelante y une el borde exterior con el interior. `arcTo` (en vez
      // de `addArc`) continúa el mismo subpath, conectando con el punto
      // actual sin líneas sueltas.
      ..arcTo(Rect.fromCircle(center: capEndC, radius: tEnd / 2), a1 + math.pi, -math.pi, false);

    // Borde interior hacia atrás, con grosor variable tStart..tEnd.
    const steps = 20;
    for (var i = steps; i >= 0; i--) {
      final ang = a0 + (a1 - a0) * (i / steps);
      final rad = r0 + tStart + (tEnd - tStart) * (i / steps);
      path.lineTo(c.dx + math.cos(ang) * rad, c.dy + math.sin(ang) * rad);
    }

    // Punta inicial: semicírculo de radio tStart/2 que cierra hasta el
    // punto de partida, también conectando al mismo subpath.
    path
      ..arcTo(Rect.fromCircle(center: capStartC, radius: tStart / 2), a0, -math.pi, false)
      ..close();

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity);
    if (blur) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.008);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.opacity != opacity ||
      oldDelegate.tStart != tStart ||
      oldDelegate.tEnd != tEnd ||
      oldDelegate.blur != blur;
}
