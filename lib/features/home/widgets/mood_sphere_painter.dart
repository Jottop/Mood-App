import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Dibuja la esfera de colores repartiendo el espacio de forma
/// **proporcional** entre todos los estados presentes.
///
/// Reglas de diseño:
/// - Con un solo estado registrado, se ve como un degradado radial
///   suave y translúcido que empieza fuerte arriba y se desvanece hacia
///   abajo — el look de "recién empezando el día".
/// - Desde el segundo estado en adelante, cada color ocupa una porción
///   **igual** (1/N) del círculo, sin importar el orden de registro. Se
///   logra pintando cada sector como un arco con su propio degradado en
///   barrido que se extiende hasta los centros de los vecinos: así todos
///   los colores participan por igual y en los límites se funden en una
///   transición suave, sin cortes bruscos.
/// - Sin registros, la esfera es casi transparente, con un borde donde
///   se mezclan colores pastel suaves (como una burbuja de jabón real).
class MoodSpherePainter extends CustomPainter {
  /// Colores de más reciente (arriba) a más antiguo (abajo). Vacío =
  /// esfera "vacía" (sin registros).
  final List<Color> colorsTopToBottom;

  /// Modo simple para tamaños chicos (miniaturas del calendario): omite
  /// los `saveLayer` y el blur del caso vacío, que a 36px son caros y
  /// apenas se notan.
  final bool simple;

  const MoodSpherePainter({
    required this.colorsTopToBottom,
    this.simple = false,
  });

  static const List<Color> _rainbow = [
    Color(0xFFFFB3C6),
    Color(0xFFFFE29A),
    Color(0xFFB9F0CB),
    Color(0xFFAED8FF),
    Color(0xFFD3BBFF),
    Color(0xFFFFB3C6),
  ];
  static const List<double> _rainbowStops = [0, 0.2, 0.4, 0.6, 0.8, 1.0];

  // Radio (arriba, compartido por todos) para el caso de un solo estado.
  static const double _singleFadeRadiusFactor = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    if (colorsTopToBottom.isEmpty) {
      if (simple) {
        _paintEmptySimple(canvas, size);
      } else {
        _paintEmpty(canvas, size);
      }
      return;
    }

    if (colorsTopToBottom.length == 1) {
      // Un solo estado: se mantiene el degradado suave y translúcido,
      // el "recién empezando el día".
      _paintSingleFade(canvas, size, colorsTopToBottom[0]);
      return;
    }

    // Dos o más estados: cada color ocupa una porción proporcional (1/N)
    // del círculo, con transiciones suaves entre ellos.
    _paintSectors(canvas, size, colorsTopToBottom);
  }

  void _paintSingleFade(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width / 2, -size.height * 0.1);
    final radius = size.height * _singleFadeRadiusFactor;
    final shader = RadialGradient(
      colors: [
        color,
        color.withValues(alpha: 0.7),
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.4, 0.72, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  /// Reparte los [colors] como **anillos concéntricos verticales** (todos
  /// con el mismo centro arriba de la burbuja, como una "sonrisa"/arco),
  /// pero de forma **proporcional**: cada color ocupa una banda de altura
  /// 1/N, sin que ninguno domine como base.
  ///
  /// Los centros de las bandas se reparten uniformemente en la altura de la
  /// burbuja. Se dibuja un solo degradado radial **opaco** cuyos stops caen
  /// en el centro de cada banda: cada color domina su banda y las
  /// transiciones son mezclas directas entre los colores vecinos (sin
  /// transparencia, así no aparece gris ni apagado).
  void _paintSectors(Canvas canvas, Size size, List<Color> colors) {
    final n = colors.length;
    final arcCenter = Offset(size.width / 2, -size.height * 0.1);
    final topY = -size.height * 0.1;
    final bottomY = size.height;
    final rhoMax = bottomY - topY;

    // Un solo degradado radial opaco que interpola directamente entre los
    // colores vecinos: los stops caen en el centro de cada banda (altura
    // 1/N), así cada color domina su banda y las transiciones son mezclas
    // reales de color (sin transparencia, sin grises).
    final stops = <double>[];
    final gradientColors = <Color>[];
    for (var i = 0; i < n; i++) {
      final rhoMid = (bottomY * (i + 0.5) / n) - topY;
      stops.add((rhoMid / rhoMax).clamp(0.0, 1.0));
      gradientColors.add(colors[i]);
    }

    final shader = RadialGradient(
      colors: gradientColors,
      stops: stops,
      tileMode: TileMode.clamp,
    ).createShader(Rect.fromCircle(center: arcCenter, radius: rhoMax));

    canvas.drawCircle(arcCenter, rhoMax, Paint()..shader = shader);
  }

  /// Esfera vacía: translúcida, con un sheen de colores pastel difuminado
  /// cerca del borde (como una burbuja de jabón real), sin ningún relleno
  /// sólido de fondo.
  ///
  /// El difuminado es un `MaskFilter.blur` sobre la máscara de alpha del
  /// trazo: no arrastra negro desde píxeles transparentes (a diferencia de
  /// `ImageFiltered`) y, como el contenido es estático, lo cachea el
  /// `RepaintBoundary` de MoodSphereVisual — el costo se paga una vez.
  void _paintEmpty(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cuerpo: leve tinte de vidrio que crece suavemente hacia el borde.
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.14),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, body);

    // Sheen con efecto de oleaje: el anillo se dibuja entre dos contornos
    // cuyo radio vibra con un seno (ondulado, no circular perfecto), y se
    // difumina con una gaussiana real. El contorno interior marca el
    // límite: la banda se queda pegada al borde y no invade el centro.
    final annulus = Path.combine(
      PathOperation.difference,
      _wavyRing(center, size, radius - size.width * 0.02, 0),
      _wavyRing(center, size, radius - size.width * 0.12, math.pi / 3),
    );
    final sheen = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.045)
      ..shader = ui.Gradient.sweep(center, [
        for (final c in _rainbow) c.withValues(alpha: 0.6),
      ], _rainbowStops);
    canvas.drawPath(annulus, sheen);

    // Borde fino y muy tenue, apenas para definir el contorno sin crear
    // un anillo marcado.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..shader = ui.Gradient.sweep(center, [
        for (final c in _rainbow) c.withValues(alpha: 0.3),
      ], _rainbowStops);
    canvas.drawCircle(center, radius - size.width * 0.015, rim);
  }

  /// Contorno cerrado de una circunferencia con radio modulado por un seno
  /// (efecto oleaje), centrado en [center]. [midRadius] es el radio medio
  /// y [phaseShift] desfasa la onda para que los dos contornos del anillo
  /// no queden perfectamente paralelos (irregularidad suave).
  static ui.Path _wavyRing(
    Offset center,
    Size size,
    double midRadius,
    double phaseShift,
  ) {
    const points = 84;
    const lobes = 11;
    final amplitude = size.width * 0.03;
    final path = ui.Path();
    for (var i = 0; i <= points; i++) {
      final theta = i / points * 2 * math.pi;
      final r = midRadius + amplitude * math.sin(lobes * theta + phaseShift);
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Versión barata de la esfera vacía (modo simple): misma rampa suave de
  /// sheen que [paint] pero con menos pasadas — para las miniaturas del
  /// calendario, donde la calidad extra no se nota.
  void _paintEmptySimple(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.1),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, body);

    final band = Paint()..style = PaintingStyle.stroke;
    const passes = [
      (width: 0.2, offset: 0.08, alpha: 0.06),
      (width: 0.13, offset: 0.055, alpha: 0.14),
      (width: 0.07, offset: 0.032, alpha: 0.24),
      (width: 0.035, offset: 0.012, alpha: 0.38),
    ];
    for (final p in passes) {
      band
        ..strokeWidth = size.width * p.width
        ..shader = ui.Gradient.sweep(center, [
          for (final c in _rainbow) c.withValues(alpha: p.alpha),
        ], _rainbowStops);
      canvas.drawCircle(center, radius - size.width * p.offset, band);
    }
  }

  @override
  bool shouldRepaint(covariant MoodSpherePainter oldDelegate) {
    return oldDelegate.simple != simple ||
        oldDelegate.colorsTopToBottom.length != colorsTopToBottom.length ||
        !_listEquals(oldDelegate.colorsTopToBottom, colorsTopToBottom);
  }

  static bool _listEquals(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }
}
