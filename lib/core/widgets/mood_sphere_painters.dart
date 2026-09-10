import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/home/widgets/mood_sphere_painter.dart';

/// Anillo del aura en la burbuja grande (fracción del widget): también es
/// el paso entre los centros de anillos consecutivos. Como el trazo usa ese
/// mismo ancho, los anillos son CONTIGUOS — el borde interno de cada uno
/// toca el borde externo del anterior y el primero pegado a la burbuja.
const double kAuraRingStep = 0.04;

/// Grosor del blur del anillo (misma escala): bajo para que los anillos se
/// lean como bandas separadas, sin dar la sensación de que se mezclan.
/// También se suma al espacio fijo reservado para el resto del glow.
const double kAuraBlurMargin = 0.01;

/// Calendario (compacto): los anillos van un poco más finos que la burbuja
/// grande y con una separación leve (el paso de centros es mayor que el
/// grosor del trazo: `gap = step - stroke`) para que se lean bien aunque
/// la burbuja sea chica y no rompan las celdas de ~40px.
const double kAuraCompactStep = 0.042;
const double kAuraCompactStroke = 0.12;

/// Cantidad de anillos de aura que se reservan de antemano ARRIBA Y ABAJO
/// de la burbuja en las burbujas grandes. El espacio es FIJO (no depende de
/// cuántos anillos haya en este momento) para que el layout no "salte" cada
/// vez que se agrega una emoción especial.
const int kReservedAuraRings = 6;

/// Devuelve los colores especiales ÚNICOS, en el ORDEN DE PRIMERA
/// APARICIÓN (la primera vez que cada emoción especial se registró). Con
/// eso el orden del aura es estable y legible: repetir una emoción que ya
/// estaba NO la reordena ni refuerza su anillo — solo aparece una vez, en
/// la posición donde entró por primera vez, siempre con la misma
/// intensidad.
List<Color> auraLayers(List<Color> colors) {
  if (colors.isEmpty) return const [];
  final seen = <int>{};
  return [
    for (final c in colors)
      if (seen.add(c.toARGB32())) c,
  ];
}

/// Trazo circular translúcido, más luminoso arriba que abajo, que refuerza
/// el contorno de la burbuja.
class MoodSphereRimPainter extends CustomPainter {
  const MoodSphereRimPainter();

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
  bool shouldRepaint(covariant MoodSphereRimPainter oldDelegate) => false;
}

/// Aura tipo "neón" alrededor de la burbuja (Home / detalle del día):
/// anillos concéntricos que crecen hacia afuera — cada emoción especial
/// (color único, en orden de primera aparición) agrega UN anillo más grande
/// que el anterior. Los anillos son CONTIGUOS: el borde interno de cada uno
/// toca el borde externo del anterior, y el primero arranca pegado a la
/// burbuja (sin separación). El glow del blur de cada anillo se funde
/// suavemente hacia el siguiente sin llegar a mezclar los colores.
///
/// Registrar varias veces la MISMA emoción no agrega nada: ni un anillo
/// nuevo, ni mayor intensidad — siempre un solo anillo al mismo alpha
/// (0.6), en la posición donde entró por primera vez.
class MoodSphereAuraPainter extends CustomPainter {
  final List<Color> colors;
  const MoodSphereAuraPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = auraLayers(colors);
    if (layers.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;
    const alpha = 0.6;
    // El centro de cada anillo se corre `kAuraRingStep` y el trazo usa ese
    // mismo ancho: así los anillos quedan contiguos, sin huecos entre ellos.
    final step = size.width * kAuraRingStep;

    for (var i = 0; i < layers.length; i++) {
      final r = baseR + step * (i + 0.5);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * kAuraRingStep
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * kAuraBlurMargin);
      paint.color = layers[i].withValues(alpha: alpha);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MoodSphereAuraPainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i].toARGB32() != colors[i].toARGB32()) return true;
    }
    return false;
  }
}

/// Versión ultra barata del aura para las miniaturas del calendario: UN
/// solo anillo fino (pegado a la burbuja) en el que los colores de las
/// emociones especiales se REPARTEN como segmentos alrededor de la
/// circunferencia, con una pequeña separación angular entre ellos (en
/// orden de primera aparición). Sin `MaskFilter.blur`.
class MoodSphereAuraSimplePainter extends CustomPainter {
  final List<Color> colors;
  const MoodSphereAuraSimplePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = auraLayers(colors);
    if (layers.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;
    const alpha = 0.6;
    // Separación angular (rad) entre los segmentos de color contiguos.
    const gap = 0.14;
    final n = layers.length;
    // Arco de cada color: reparte 2π quitando un hueco por segmento.
    final segmentSpan = math.max(0.0, (2 * math.pi - gap * n) / n);

    // Un solo anillo separado de la burbuja: el centro queda dos pasos
    // afuera del borde, así queda un hueco visible entre la burbuja y el
    // interior del anillo (el trazo grueso no la tapa), con los colores en
    // arcos.
    final r = baseR + size.width * kAuraCompactStep * 2;
    for (var i = 0; i < n; i++) {
      final start = i * (segmentSpan + gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * kAuraCompactStroke;
      paint.color = layers[i].withValues(alpha: alpha);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        segmentSpan,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MoodSphereAuraSimplePainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i].toARGB32() != colors[i].toARGB32()) return true;
    }
    return false;
  }
}

/// Reflejo tipo "media luna" que simula el vidrio de una burbuja: una cinta
/// blanca cuyo grosor cambia a lo largo del arco, de [tStart] (en
/// [startAngle]) hasta [tEnd] (al final del barrido), con borde difuminado
/// por gaussiana. Configurable para colocarlo en cualquier zona y
/// orientación de la esfera.
class MoodSphereCrescentPainter extends CustomPainter {
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

  const MoodSphereCrescentPainter({
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
      // adelante y une el borde exterior con el interior.
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
  bool shouldRepaint(covariant MoodSphereCrescentPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.opacity != opacity ||
      oldDelegate.tStart != tStart ||
      oldDelegate.tEnd != tEnd ||
      oldDelegate.blur != blur;
}

/// Pinta la burbuja completa (base + efecto vidrio + borde + aura) en un
/// `Canvas` arbitrario. Es la misma composición que renderiza
/// `MoodSphereVisual`, publicada como painter para poder rasterizarla
/// offscreen (por ejemplo con `ui.PictureRecorder` para el widget del
/// escritorio) y así garantizar que el resultado es idéntico a lo que se ve
/// dentro de la app.
class MoodSphereVisualPainter extends CustomPainter {
  final List<Color> colorsTopToBottom;

  /// Si es `true`, se omite el efecto glass (brillos, arcos tipo media
  /// luna con blur) y el painter base va en modo simple.
  final bool glassEffects;

  /// Modo compacto para miniaturas (calendario): una sola media luna
  /// nítida, el blob superior y el painter simple.
  final bool compact;

  /// Colores de las emociones "especiales" presentes. Vacío = sin aura.
  final List<Color> auraColors;

  const MoodSphereVisualPainter({
    required this.colorsTopToBottom,
    this.glassEffects = true,
    this.compact = false,
    this.auraColors = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintSphere(
      canvas,
      size,
      colorsTopToBottom: colorsTopToBottom,
      glassEffects: glassEffects,
      compact: compact,
      auraColors: auraColors,
    );
  }

  /// Método estático para pintar la burbuja en un [Canvas] de destino:
  /// recorta el interior de la esfera, dibuja base + vidrio + borde, y el
  /// aura por fuera (sin clip). Reutilizable para escenas compuestas
  /// (p. ej. la comparación del widget).
  static void paintSphere(
    Canvas canvas,
    Size size, {
    required List<Color> colorsTopToBottom,
    bool glassEffects = true,
    bool compact = false,
    List<Color> auraColors = const [],
  }) {
    final simple = !glassEffects || compact;

    // Interior de la esfera (todo recortado al círculo).
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));

    MoodSpherePainter(colorsTopToBottom: colorsTopToBottom, simple: simple).paint(canvas, size);

    if (glassEffects) {
      // Blob principal de brillo, arriba a la izquierda: el degradado ya es
      // suave, sin blur adicional (misma geometría que en `MoodSphereVisual`).
      _drawGlossBlob(
        canvas,
        center: Offset(size.width * 0.25, size.height * 0.25),
        radius: size.width * 0.35,
        colors: [
          Colors.white.withValues(alpha: 0.43),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0, 0.55, 1],
      );

      if (!compact) {
        // Blob secundario inferior derecho: espejo diagonal del principal.
        _drawGlossBlob(
          canvas,
          center: Offset(size.width * 0.81, size.height * 0.83),
          radius: size.width * 0.35,
          colors: [
            Colors.white.withValues(alpha: 0.58),
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0, 0.55, 1],
        );
      }

      // Reflejo superior en forma de arco (media luna), concéntrico con la
      // burbuja. En modo compacto se dibuja nítido (sin blur).
      MoodSphereCrescentPainter(
        rect: Rect.fromCircle(
          center: Offset(size.width * 0.46, size.height * 0.39),
          radius: size.width * 0.25,
        ),
        startAngle: 3.3,
        sweepAngle: 1.6,
        tStart: size.width * 0.09,
        tEnd: size.width * 0.02,
        blur: !compact,
      ).paint(canvas, size);

      if (!compact) {
        // Reflejo inferior derecho: espejo del arco superior.
        MoodSphereCrescentPainter(
          rect: Rect.fromLTWH(
            size.width * 0.33,
            size.height * 0.37,
            size.width * 0.5,
            size.height * 0.5,
          ),
          startAngle: 6.74,
          sweepAngle: 1.1,
          opacity: 0.65,
          tStart: size.width * 0.048,
          tEnd: size.width * 0.025,
        ).paint(canvas, size);
      }
    }

    // Borde translúcido para reforzar el contorno de burbuja.
    const MoodSphereRimPainter().paint(canvas, size);
    canvas.restore();

    // Aura por fuera del borde (sin clip, como en la app).
    if (auraColors.isNotEmpty) {
      (compact
              ? MoodSphereAuraSimplePainter(colors: auraColors)
              : MoodSphereAuraPainter(colors: auraColors))
          .paint(canvas, size);
    }
  }

  static void _drawGlossBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required List<Color> colors,
    required List<double> stops,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: colors, stops: stops)
            .createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant MoodSphereVisualPainter oldDelegate) {
    return oldDelegate.glassEffects != glassEffects ||
        oldDelegate.compact != compact ||
        !_sameColors(oldDelegate.colorsTopToBottom, colorsTopToBottom) ||
        !_sameColors(oldDelegate.auraColors, auraColors);
  }

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }
}