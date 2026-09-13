import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const _kFruitCount = 5;

/// Nombres de las frutas disponibles para el avatar, en orden de índice.
const _kFruitNames = ['Fresa', 'Banana', 'Sandía', 'Manzana', 'Naranja'];

/// Clave de avatar para cada índice (`fruit_0`..`fruit_4`).
String fruitAvatarKey(int index) => 'fruit_$index';

/// Nombre visible de la fruta con índice [index].
String fruitAvatarName(int index) => index >= 0 && index < _kFruitCount
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

  /// Clave de avatar: `fruit_0`..`fruit_4` o null (inicial).
  final String? avatar;
  final String initial;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;

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
  });

  @override
  Widget build(BuildContext context) {
    final fruitIndex = avatar == null ? null : _fruitIndexOf(avatar!);
    Widget body;
    if (fruitIndex == null) {
      body = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: foreground,
            decoration: TextDecoration.none,
          ),
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
            // El anillo de selección se pinta ENCIMA de la fruta (si no, el
            // clip del círculo lo taparía).
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.ink : Colors.transparent,
                    width: 2,
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
    final match = RegExp(r'^fruit_([0-4])$').firstMatch(key);
    return match == null ? null : int.parse(match.group(1)!);
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

    switch (fruitIndex % _kFruitCount) {
      case 0:
        _paintStrawberry(canvas);
      case 1:
        _paintBanana(canvas);
      case 2:
        _paintWatermelon(canvas);
      case 3:
        _paintApple(canvas);
      default:
        _paintOrangeSlice(canvas);
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

  // ----- Rodaja de sandía -----
  void _paintWatermelon(Canvas canvas) {
    final flesh = Paint()..color = const Color(0xFFF26E7E);
    canvas.drawCircle(const Offset(0, -0.28), 0.95, flesh);

    // Gajos más claros.
    final wedge = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    for (var i = -2; i <= 2; i++) {
      final angle = i * 0.45;
      canvas.drawLine(
        const Offset(0, -0.28),
        Offset(math.sin(angle) * 0.9, -0.28 - math.cos(angle) * 0.9),
        wedge,
      );
    }

    // Semillas.
    final seed = Paint()..color = const Color(0xFF3A2A20);
    const seeds = [
      Offset(-0.38, -0.15),
      Offset(0.02, 0.05),
      Offset(0.4, -0.2),
      Offset(0.0, -0.55),
    ];
    for (final s in seeds) {
      canvas.drawOval(
        Rect.fromCenter(center: s, width: 0.09, height: 0.06),
        seed,
      );
    }

    // Cáscara verde por debajo (asoma por el borde recortado).
    final rind = Paint()
      ..color = const Color(0xFF3E8E4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.16;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, -0.28), width: 1.9, height: 1.9),
      math.pi,
      math.pi,
      false,
      rind,
    );

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