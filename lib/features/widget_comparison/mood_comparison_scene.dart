import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../core/widgets/mood_sphere_painters.dart';
import 'widget_cache_store.dart';

/// Tamaño lógico (dp) de la escena del widget según la disposición. El
/// launcher escala la imagen al tamaño real del widget conservando la
/// proporción (fitCenter), así el diseño no se deforma al redimensionarlo.
///
/// Horizontal: 360×220 (~1.64:1), la que maximiza el diámetro de las burbujas
/// en un widget 2×2 . Vertical: 220×420 en retrato, con las burbujas apiladas
/// de arriba a abajo (se recomienda estirar el widget en vertical).
const Size kComparisonSceneSize = Size(360, 220);
const Size kComparisonSceneVerticalSize = Size(220, 420);

/// Tamaño de la escena para la disposición indicada.
Size comparisonSceneSize(WidgetLayout layout) =>
    layout == WidgetLayout.vertical
        ? kComparisonSceneVerticalSize
        : kComparisonSceneSize;

/// Pinta la escena completa del widget de comparación (transparente): de 1 a
/// 3 burbujas (la primera siempre "Yo") con su etiqueta, dispuestas en
/// horizontal (lado a lado) o vertical (apiladas). Es la misma composición
/// que `MoodSphereVisual`, rasterizable fuera del árbol de widgets para
/// obtener el PNG que muestra el AppWidget.
class MoodComparisonScenePainter extends CustomPainter {
  final List<DayBubbleData> bubbles;
  final List<String> labels;
  final WidgetLayout layout;

  const MoodComparisonScenePainter({
    required this.bubbles,
    required this.labels,
    required this.layout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (layout) {
      case WidgetLayout.horizontal:
        _paintHorizontal(canvas, size);
        break;
      case WidgetLayout.vertical:
        _paintVertical(canvas, size);
        break;
    }
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    final n = bubbles.length;
    if (n == 0) return;
    final margin = size.width * 0.04;
    final gap = size.width * 0.033;
    final cellWidth = (size.width - 2 * margin - gap * (n - 1)) / n;

    final labelFont = size.height * 0.10;
    final labelTop = size.height - (labelFont * 1.55 + 6);
    // Las burbujas se dimensionan por el ANCHO: en horizontal mandan las
    // columnas (cabinas de ancho `cellWidth`), así varias caben lado a lado.
    final bubbleDiameter = math.min(size.width * 0.44, cellWidth * 0.9);
    final bubbleCenterY = size.height * 0.42;

    for (var i = 0; i < n; i++) {
      final cellLeft = margin + i * (cellWidth + gap);
      final centerX = cellLeft + cellWidth / 2;
      _paintBubble(
          canvas, Size(bubbleDiameter, bubbleDiameter),
          Offset(centerX, bubbleCenterY), bubbles[i]);
      _paintLabel(
        canvas,
        centerX,
        labelTop + (labelFont * 1.55 - labelFont) / 2,
        cellWidth,
        i < labels.length ? labels[i] : '',
        labelFont,
      );
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    final n = bubbles.length;
    if (n == 0) return;
    final margin = size.width * 0.04;
    final bubbleDiameter = size.width * 0.40;
    final labelFont = bubbleDiameter * 0.20;
    final labelBand = labelFont * 1.6;
    final rowStep = bubbleDiameter + labelBand;
    final total = n * rowStep;
    final startY = math.max(margin, (size.height - total) / 2);
    final centerX = size.width / 2;

    for (var i = 0; i < n; i++) {
      final y = startY + rowStep * i;
      _paintBubble(canvas, Size(bubbleDiameter, bubbleDiameter),
          Offset(centerX, y + bubbleDiameter / 2), bubbles[i]);
      _paintLabel(
        canvas,
        centerX,
        y + bubbleDiameter + (labelBand - labelFont) / 2,
        size.width - 2 * margin,
        i < labels.length ? labels[i] : '',
        labelFont,
      );
    }
  }

  void _paintBubble(Canvas canvas, Size size, Offset center, DayBubbleData data) {
    canvas.save();
    canvas.translate(center.dx - size.width / 2, center.dy - size.height / 2);
    MoodSphereVisualPainter.paintSphere(
      canvas,
      size,
      colorsTopToBottom: data.colorsTopToBottom,
      // El aura del widget va aparte (_WidgetSceneAuraPainter): fina y
      // recortada para no pelear con las etiquetas en un lienzo ancho.
      // El cuerpo de la burbuja conserva el look de vidrio completo.
      auraColors: const [],
    );
    _WidgetSceneAuraPainter(colors: data.auraColors).paint(canvas, size);
    canvas.restore();
  }

  void _paintLabel(Canvas canvas, double centerX, double top, double maxWidth, String text, double fontSize) {
    final labelStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
  }

  @override
  bool shouldRepaint(covariant MoodComparisonScenePainter oldDelegate) => true;
}

/// Aura fina del widget: anillos concéntricos delgados y nítidos (sin blur)
/// alrededor de las burbujas, en el orden de primera aparición de las
/// emociones especiales. El paso y el trazo escalan con la ALTURA de la
/// burbuja y se recorta a [maxRings].
class _WidgetSceneAuraPainter extends CustomPainter {
  final List<Color> colors;
  const _WidgetSceneAuraPainter({required this.colors});

  /// Máximos anillos que caben sin pisar las etiquetas; con más emociones
  /// especiales distintas se conservan las primeras.
  static const int maxRings = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final layers = auraLayers(colors);
    if (layers.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;
    final step = size.height * 0.03;
    final stroke = size.height * 0.015;
    final shown = math.min(layers.length, maxRings);
    for (var i = 0; i < shown; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      paint.color = layers[i].withValues(alpha: 0.5);
      canvas.drawCircle(center, baseR + step * (i + 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WidgetSceneAuraPainter oldDelegate) {
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i].toARGB32() != colors[i].toARGB32()) return true;
    }
    return false;
  }
}

/// Preview en vivo de la escena: muestra el MISMO PNG byte a byte que se
/// instala en el AppWidget (generado con [renderComparisonScenePng]), sobre
/// el degradado pastel que define `widget_bg.xml`. Al rasterizar fuera del
/// árbol de widgets y mostrarlo como imagen, la preview no puede divergir
/// de lo que queda en el escritorio. Se regenera cuando cambia alguna burbuja,
/// alguna etiqueta o la disposición.
class MoodComparisonScene extends StatefulWidget {
  final List<DayBubbleData> bubbles;
  final List<String> labels;
  final WidgetLayout layout;

  const MoodComparisonScene({
    super.key,
    required this.bubbles,
    required this.labels,
    required this.layout,
  });

  @override
  State<MoodComparisonScene> createState() => _MoodComparisonSceneState();
}

class _MoodComparisonSceneState extends State<MoodComparisonScene> {
  Uint8List? _png;
  List<Object?>? _signature;
  bool _rendering = false;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  @override
  void didUpdateWidget(covariant MoodComparisonScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature != _makeSignature()) {
      _refreshPreview();
    }
  }

  /// Firma de los datos que afectan al dibujo; cualquier cambio fuerza una
  /// re-rasterización.
  List<Object?> _makeSignature() {
    final sig = <Object?>[widget.layout];
    for (var i = 0; i < widget.bubbles.length; i++) {
      final b = widget.bubbles[i];
      sig.add(i < widget.labels.length ? widget.labels[i] : '');
      for (final c in b.colorsTopToBottom) {
        sig.add(c.toARGB32());
      }
      for (final c in b.auraColors) {
        sig.add(c.toARGB32());
      }
    }
    return sig;
  }

  Future<void> _refreshPreview() async {
    if (_rendering) return;
    final sig = _makeSignature();
    if (_signature == sig && _png != null) return;
    _signature = sig;
    _rendering = true;
    try {
      final bytes = await renderComparisonScenePng(
        widget.bubbles,
        widget.labels,
        layout: widget.layout,
      );
      if (!mounted) return;
      // Los datos cambiaron mientras se renderizaba: se mantiene el frame
      // anterior y el próximo `didUpdateWidget` relanza la rasterización.
      if (_signature != sig) return;
      setState(() => _png = bytes);
    } catch (_) {
      // Si la rasterización fallara, se conserva el último frame (o vacío).
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    final sceneSize = comparisonSceneSize(widget.layout);
    return AspectRatio(
      aspectRatio: sceneSize.width / sceneSize.height,
      child: Container(
        decoration: BoxDecoration(
          // Mismo degradado que `widget_bg.xml` (lavanda arriba → celeste abajo).
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBDFF7), Color(0xFFD9E9FB)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: png == null
            ? const SizedBox.expand()
            : Image.memory(png, fit: BoxFit.fill, gaplessPlayback: true),
      ),
    );
  }
}

/// Rasteriza la escena fuera del árbol de widgets y la devuelve como PNG en
/// bytes. El [pixelRatio] sube la resolución para que en pantallas con
/// densidad alta no se vea pixelada.
Future<Uint8List> renderComparisonScenePng(
  List<DayBubbleData> bubbles,
  List<String> labels, {
  required WidgetLayout layout,
  double pixelRatio = 2,
}) async {
  final sceneSize = comparisonSceneSize(layout);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  MoodComparisonScenePainter(
    bubbles: bubbles,
    labels: labels,
    layout: layout,
  ).paint(canvas, sceneSize);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (sceneSize.width * pixelRatio).round(),
    (sceneSize.height * pixelRatio).round(),
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('No se pudo codificar el PNG de comparación.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}