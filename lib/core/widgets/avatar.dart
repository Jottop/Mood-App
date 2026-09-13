import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cantidad total de avatares de fruta/verdura disponibles (`fruit_0`..`fruit_9`).
const int fruitAvatarCount = 10;

/// Nombres de los avatares disponibles, en orden de índice.
const _kFruitNames = [
  'Fresa',
  'Banana',
  'Sandía',
  'Manzana',
  'Naranja',
  'Durazno',
  'Limón',
  'Zanahoria',
  'Mango',
  'Berenjena',
];

/// Clave de avatar para cada índice (`fruit_0`..`fruit_9`).
String fruitAvatarKey(int index) => 'fruit_$index';

/// Nombre visible del avatar con índice [index].
String fruitAvatarName(int index) =>
    index >= 0 && index < fruitAvatarCount && index < _kFruitNames.length
        ? _kFruitNames[index]
        : 'Fresa';

/// Avatar circular que se usa en la píldora del hub de amigos, en el perfil
/// de un amigo (esquina de la burbuja) y como selector de perfil.
///
/// Si el perfil tiene avatar de fruta, dibuja la fruta animada "asomando"
/// desde el borde inferior del círculo (su parte baja queda recortada por el
/// clip del círculo). Si no, muestra la inicial con el color de fondo.
class AvatarBadge extends StatelessWidget {
  final double size;
  final Color background;
  final Color foreground;

  /// Clave de avatar: `fruit_0`..`fruit_9` o null (inicial).
  final String? avatar;
  final String initial;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Ancho del anillo de selección (se dibuja POR FUERA del círculo, sin
  /// tapar la imagen).
  final double ringWidth;

  const AvatarBadge({
    super.key,
    this.size = 34,
    required this.background,
    required this.foreground,
    this.avatar,
    required this.initial,
    this.selected = false,
    this.onTap,
    this.tooltip,
    this.ringWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final fruitIndex = avatar == null ? null : _fruitIndexOf(avatar!);
    final Widget body;
    if (fruitIndex == null) {
      body = SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            // El anillo de selección va por fuera del círculo (trazo con el
            // centro sobre el borde exterior), nunca sobre la imagen.
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SelectionRingPainter(
                      color: AppColors.ink,
                      stroke: ringWidth,
                      size: size,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      body = SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            // Fondo del círculo detrás de la fruta (la fruta tiene zonas
            // transparentes, p. ej. entre los gajos de la banana).
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
              ),
            ),
            Positioned.fill(
              child: ClipOval(
                child: FruitAvatar(fruitIndex: fruitIndex, size: size),
              ),
            ),
            // Igual que en modo inicial: el anillo se dibuja por fuera del
            // círculo, sin recortar ni tapar la fruta.
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SelectionRingPainter(
                      color: AppColors.ink,
                      stroke: ringWidth,
                      size: size,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: tooltip,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      ),
    );
  }

  static int? _fruitIndexOf(String key) {
    final match = RegExp(r'^fruit_([0-9])$').firstMatch(key);
    return match == null ? null : int.parse(match.group(1)!);
  }
}

/// Pinta el anillo de selección como un trazo centrado sobre el borde
/// EXTERIOR del círculo del avatar (`radius = size/2 + stroke/2`), de modo
/// que nunca tapa la imagen.
class _SelectionRingPainter extends CustomPainter {
  final Color color;
  final double stroke;
  final double size;

  _SelectionRingPainter({required this.color, required this.stroke, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 + stroke / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SelectionRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.size != size;
}

/// Avatar enmarcado para las esquinas de las pantallas (debajo de la burbuja
/// del Home y en el perfil de un amigo): un anillo blanco con sombra suave
/// que lo destaca del fondo sin pegarse a la burbuja.
class FramedAvatar extends StatelessWidget {
  final double size;
  final Color background;
  final Color foreground;

  /// Clave de avatar: `fruit_0`..`fruit_9` o null (inicial).
  final String? avatar;
  final String initial;
  final VoidCallback? onTap;
  final String? tooltip;

  const FramedAvatar({
    super.key,
    this.size = 56,
    required this.background,
    required this.foreground,
    this.avatar,
    required this.initial,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AvatarBadge(
        size: size,
        background: background,
        foreground: foreground,
        avatar: avatar,
        initial: initial,
        onTap: onTap,
        tooltip: tooltip,
      ),
    );
  }
}

/// Fruta animada que "se asoma" desde el borde inferior del círculo:
/// anclada abajo, con un balanceo lento de sube y baja y una leve inclinación.
/// Usa un CustomPainter para no depender de assets ni animaciones externas.
class FruitAvatar extends StatefulWidget {
  final int fruitIndex;
  final double size;

  const FruitAvatar({super.key, required this.fruitIndex, this.size = 34});

  @override
  State<FruitAvatar> createState() => _FruitAvatarState();
}

class _FruitAvatarState extends State<FruitAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          // Sube y baja suave (la fruta "asoma" más y menos) + leve vaivén.
          final bob = math.sin(v * 2 * math.pi) * widget.size * 0.025;
          final tilt = math.sin(v * 2 * math.pi + math.pi / 2) * 0.05;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _FruitPainter(
              fruitIndex: widget.fruitIndex,
              bob: bob,
              tilt: tilt,
            ),
          );
        },
      ),
    );
  }
}

class _FruitPainter extends CustomPainter {
  final int fruitIndex;
  final double bob;
  final double tilt;

  _FruitPainter({required this.fruitIndex, required this.bob, required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Recorte defensivo al círculo del avatar (el ClipOval exterior ya lo
    // hace, pero así el painter es seguro por sí solo).
    canvas.clipRRect(RRect.fromRectAndCorners(
      Rect.fromCircle(center: Offset(w / 2, w / 2), radius: w / 2),
      topLeft: const Radius.circular(999),
      topRight: const Radius.circular(999),
      bottomLeft: const Radius.circular(999),
      bottomRight: const Radius.circular(999),
    ));

    canvas.save();
    canvas.translate(w / 2 + bob * 0.4, w * 0.86 + bob);
    canvas.rotate(tilt);
    // Unidad de dibujo relativa al tamaño del círculo.
    final u = w * 0.5;
    canvas.scale(u);

    switch (fruitIndex % fruitAvatarCount) {
      case 0:
        _paintStrawberry(canvas);
      case 1:
        _paintBanana(canvas);
      case 2:
        _paintWatermelon(canvas);
      case 3:
        _paintApple(canvas);
      case 4:
        _paintOrangeSlice(canvas);
      case 5:
        _paintPeach(canvas);
      case 6:
        _paintLemon(canvas);
      case 7:
        _paintCarrot(canvas);
      case 8:
        _paintMango(canvas);
      default:
        _paintEggplant(canvas);
    }
    canvas.restore();
  }

  // ----- Carita común (ojos + sonrisa + mejillas) -----
  void _paintFace(Canvas canvas) {
    final dark = Paint()..color = const Color(0xFF2B3A4A);
    canvas.drawCircle(const Offset(-0.16, 0.02), 0.052, dark);
    canvas.drawCircle(const Offset(0.16, 0.02), 0.052, dark);

    final smile = Paint()
      ..color = const Color(0xFF2B3A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 0.02), width: 0.18, height: 0.14),
      0.25 * math.pi,
      0.5 * math.pi,
      false,
      smile,
    );

    final blush = Paint()..color = const Color(0x66FF8A9B);
    canvas.drawCircle(const Offset(-0.32, 0.18), 0.08, blush);
    canvas.drawCircle(const Offset(0.32, 0.18), 0.08, blush);
  }

  // ----- Fresa -----
  void _paintStrawberry(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFF05656);
    final path = Path()
      ..moveTo(0, -0.72)
      ..cubicTo(-0.52, -0.86, -0.95, -0.5, -0.92, 0.02)
      ..cubicTo(-0.88, 0.52, -0.2, 0.85, 0.0, 1.0)
      ..cubicTo(0.2, 0.85, 0.88, 0.52, 0.92, 0.02)
      ..cubicTo(0.95, -0.5, 0.52, -0.86, 0.0, -0.72)
      ..close();
    canvas.drawPath(path, body);

    final seed = Paint()..color = const Color(0xFFFBF0C2);
    const seeds = [
      Offset(-0.32, -0.28),
      Offset(0.34, -0.3),
      Offset(0.0, -0.4),
      Offset(-0.46, -0.02),
      Offset(0.46, -0.02),
      Offset(-0.18, 0.24),
      Offset(0.2, 0.26),
    ];
    for (final s in seeds) {
      canvas.drawOval(
        Rect.fromCenter(center: s, width: 0.08, height: 0.11),
        seed,
      );
    }

    // Hojitas de la corona.
    final leaf = Paint()..color = const Color(0xFF4E9B4E);
    for (var i = -1; i <= 1; i++) {
      final center = Offset(i * 0.22, -0.95 + (i == 0 ? -0.08 : 0.0));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 0.16, height: 0.3),
        leaf,
      );
      canvas.restore();
    }

    _paintFace(canvas);
  }

  // ----- Banana (curva "∪" con las puntas hacia arriba) -----
  void _paintBanana(Canvas canvas) {
    final yellow = Paint()..color = const Color(0xFFF7C923);
    final path = Path()
      ..moveTo(-0.85, -0.5)
      ..cubicTo(-0.55, -0.18, 0.55, -0.18, 0.85, -0.5)
      ..cubicTo(0.78, 0.05, 0.4, 0.68, 0.0, 0.78)
      ..cubicTo(-0.4, 0.68, -0.78, 0.05, -0.85, -0.5)
      ..close();
    canvas.drawPath(path, yellow);

    final tip = Paint()..color = const Color(0xFF8A5A2B);
    canvas.drawCircle(const Offset(-0.85, -0.5), 0.09, tip);
    canvas.drawCircle(const Offset(0.85, -0.5), 0.09, tip);

    final shade = Paint()
      ..color = const Color(0x33B8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 0.12), width: 0.6, height: 0.5),
      0.15 * math.pi,
      math.pi * 0.7,
      false,
      shade,
    );

    _paintFace(canvas);
  }

  // ----- Rodaja de sandía (vista en perspectiva) -----
  void _paintWatermelon(Canvas canvas) {
    // Óvalos concéntricos de la rodaja: cáscara verde, pulpa blanca y carne
    // rosada. El borde inferior queda recortado por el clip del círculo.
    const center = Offset(0, -0.18);
    final rind = Paint()..color = const Color(0xFF2F7D4F);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 2.05, height: 1.9),
      rind,
    );
    final pith = Paint()..color = const Color(0xFFEAF3E0);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 1.62, height: 1.5),
      pith,
    );
    final flesh = Paint()..color = const Color(0xFFF26E7E);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 1.32, height: 1.22),
      flesh,
    );

    // Gajos: líneas blancas que van del centro al borde de la carne.
    final wedge = Paint()
      ..color = const Color(0x8AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi / 2 + (i - 3) * 0.55;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle) * 0.62, math.sin(angle) * 0.56),
        wedge,
      );
    }

    // Semillas sobre la cara cortada.
    final seed = Paint()..color = const Color(0xFF3A2A20);
    const seeds = [
      Offset(-0.33, -0.28),
      Offset(0.34, -0.16),
      Offset(0.06, -0.06),
      Offset(-0.18, 0.14),
      Offset(0.22, 0.18),
    ];
    for (final s in seeds) {
      canvas.drawOval(
        Rect.fromCenter(center: s, width: 0.08, height: 0.06),
        seed,
      );
    }

    _paintFace(canvas);
  }

  // ----- Durazno -----
  void _paintPeach(Canvas canvas) {
    final base = Paint()..color = const Color(0xFFF9C28B);
    canvas.drawCircle(const Offset(0, -0.08), 0.85, base);
    // Rubor rosado en la parte baja.
    final blush = Paint()..color = const Color(0xFFF6897A);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.08), width: 1.02, height: 0.68),
      blush,
    );
    // Surco vertical típico del durazno.
    final crease = Paint()
      ..color = const Color(0xFFDE8A5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.78), const Offset(0, 0.78), crease);
    // Rabito + hojita.
    final stem = Paint()
      ..color = const Color(0xFF7A5230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.85), const Offset(0, -1.02), stem);
    final leaf = Paint()..color = const Color(0xFF4E9B4E);
    canvas.save();
    canvas.translate(0.24, -0.95);
    canvas.rotate(0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.18, height: 0.4),
      leaf,
    );
    canvas.restore();

    _paintFace(canvas);
  }

  // ----- Limón -----
  void _paintLemon(Canvas canvas) {
    final yellow = Paint()..color = const Color(0xFFF6E27A);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.05), width: 0.95, height: 1.35),
      yellow,
    );
    // Pezones (bultitos puntiagudos de arriba y abajo; el de abajo asoma por
    // el clip del círculo).
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.72), width: 0.3, height: 0.24),
      yellow,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.78), width: 0.28, height: 0.22),
      yellow,
    );
    // Motitas de textura de la cáscara.
    final dimple = Paint()..color = const Color(0xFFE4CB57);
    const spots = [
      Offset(-0.28, -0.3),
      Offset(0.3, -0.05),
      Offset(-0.12, 0.34),
      Offset(0.2, 0.4),
    ];
    for (final s in spots) {
      canvas.drawCircle(s, 0.055, dimple);
    }
    // Brillo tenue.
    final shine = Paint()..color = const Color(0x55FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-0.26, -0.4), width: 0.3, height: 0.2),
      shine,
    );
    // Rabito + hojita.
    final stem = Paint()
      ..color = const Color(0xFF7A5230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.85), const Offset(0, -1.06), stem);
    final leaf = Paint()..color = const Color(0xFF4E9B4E);
    canvas.save();
    canvas.translate(0.22, -0.98);
    canvas.rotate(0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.18, height: 0.38),
      leaf,
    );
    canvas.restore();

    _paintFace(canvas);
  }

  // ----- Zanahoria -----
  void _paintCarrot(Canvas canvas) {
    // Penacho de hojas (detrás de la zanahoria: el cuerpo tapa sus bases).
    final darkLeaf = Paint()..color = const Color(0xFF4E9B4E);
    final lightLeaf = Paint()..color = const Color(0xFF6ABE5E);
    const tuft = [
      (-0.24, -0.55, 0.4),
      (0.0, -0.05, 0.46),
      (0.24, 0.55, 0.4),
      (-0.12, -0.3, 0.36),
      (0.12, 0.3, 0.36),
    ];
    for (final (dx, rot, len) in tuft) {
      canvas.save();
      canvas.translate(dx, -0.3);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -0.2), width: 0.12, height: len),
        rot.abs() < 0.3 ? lightLeaf : darkLeaf,
      );
      canvas.restore();
    }

    // Cuerpo cónico que baja hasta el borde del clip.
    final body = Paint()..color = const Color(0xFFF08A24);
    final path = Path()
      ..moveTo(-0.34, -0.26)
      ..cubicTo(-0.38, 0.15, -0.16, 0.78, 0.0, 1.06)
      ..cubicTo(0.16, 0.78, 0.38, 0.15, 0.34, -0.26)
      ..cubicTo(0.18, -0.4, -0.18, -0.4, -0.34, -0.26)
      ..close();
    canvas.drawPath(path, body);

    // Acanaladuras horizontales típicas.
    final ridge = Paint()
      ..color = const Color(0xFFD97415)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-0.32, -0.08), const Offset(0.32, -0.08), ridge);
    canvas.drawLine(const Offset(-0.26, 0.15), const Offset(0.26, 0.15), ridge);
    canvas.drawLine(const Offset(-0.17, 0.36), const Offset(0.17, 0.36), ridge);

    _paintFace(canvas);
  }

  // ----- Mango -----
  void _paintMango(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFF5B42E);
    final path = Path()
      ..moveTo(0.0, -0.8)
      ..cubicTo(0.42, -0.55, 0.48, 0.05, 0.4, 0.55)
      ..cubicTo(0.34, 0.88, 0.14, 1.06, 0.0, 1.06)
      ..cubicTo(-0.14, 1.04, -0.3, 0.82, -0.34, 0.5)
      ..cubicTo(-0.4, -0.05, -0.28, -0.55, 0.0, -0.8)
      ..close();
    canvas.drawPath(path, body);
    // Rubor rojizo en el costado derecho (recortado al cuerpo).
    final blush = Paint()..color = const Color(0xFFF2765C);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.24, -0.05), width: 0.7, height: 1.1),
      blush,
    );
    canvas.restore();
    // Rabito.
    final stem = Paint()
      ..color = const Color(0xFF6B4A26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.78), const Offset(0.03, -0.98), stem);

    _paintFace(canvas);
  }

  // ----- Berenjena -----
  void _paintEggplant(Canvas canvas) {
    final body = Paint()..color = const Color(0xFF6B46A5);
    final path = Path()
      ..moveTo(0.0, -0.55)
      ..cubicTo(0.42, -0.45, 0.62, 0.02, 0.55, 0.4)
      ..cubicTo(0.48, 0.74, 0.22, 0.98, 0.0, 1.08)
      ..cubicTo(-0.22, 0.98, -0.48, 0.74, -0.55, 0.4)
      ..cubicTo(-0.62, 0.02, -0.42, -0.45, 0.0, -0.55)
      ..close();
    canvas.drawPath(path, body);
    // Sombreado lateral (recortado al cuerpo).
    final shade = Paint()
      ..color = const Color(0xFF4C2F7E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.16
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0.16, 0.08), width: 1.0, height: 1.2),
      -0.5,
      1.5,
      false,
      shade,
    );
    canvas.restore();
    // Tapa verde del tallo (cáliz) + rabito.
    final cap = Paint()..color = const Color(0xFF4E9B4E);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.56), width: 0.26, height: 0.18),
      cap,
    );
    final stem = Paint()
      ..color = const Color(0xFF3D7A3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.62), const Offset(0, -0.82), stem);

    _paintFace(canvas);
  }

  // ----- Manzana -----
  void _paintApple(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFE84C3D);
    canvas.drawCircle(const Offset(0, -0.05), 0.78, body);

    final light = Paint()..color = const Color(0x55FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-0.3, -0.35), width: 0.34, height: 0.22),
      light,
    );

    // Hojita + rabito en la parte superior.
    final stem = Paint()
      ..color = const Color(0xFF7A5230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -0.78), const Offset(0.06, -1.05), stem);
    final leaf = Paint()..color = const Color(0xFF49A84B);
    canvas.save();
    canvas.translate(0.16, -0.92);
    canvas.rotate(0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.2, height: 0.42),
      leaf,
    );
    canvas.restore();

    _paintFace(canvas);
  }

  // ----- Rodaja de naranja -----
  void _paintOrangeSlice(Canvas canvas) {
    final pith = Paint()..color = const Color(0xFFFFF3DC);
    canvas.drawCircle(const Offset(0, -0.05), 0.95, pith);

    // Gajos en dos tonos de naranja.
    const sectors = 6;
    const colors = [Color(0xFFF9A825), Color(0xFFF57F17)];
    final lines = Paint()
      ..color = const Color(0xFFFFF3DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    for (var i = 0; i < sectors; i++) {
      final start = i * 2 * math.pi / sectors;
      const sweep = 2 * math.pi / sectors;
      final sector = Paint()..color = colors[i % 2];
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -0.05), width: 1.6, height: 1.6),
        start + 0.05,
        sweep - 0.1,
        true,
        sector,
      );
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(start + sweep) * 0.8,
            -0.05 + math.sin(start + sweep) * 0.8),
        lines,
      );
    }

    final rind = Paint()
      ..color = const Color(0xFFE8850C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;
    canvas.drawCircle(const Offset(0, -0.05), 0.9, rind);

    _paintFace(canvas);
  }

  @override
  bool shouldRepaint(_FruitPainter oldDelegate) =>
      oldDelegate.fruitIndex != fruitIndex ||
      (oldDelegate.bob - bob).abs() > 0.0001 ||
      (oldDelegate.tilt - tilt).abs() > 0.0001;
}