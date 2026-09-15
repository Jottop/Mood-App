import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../core/widgets/mood_sphere_painters.dart';

/// Disposición de las burbujas en el widget del escritorio.
enum WidgetLayout {
  /// Burbujas lado a lado (escena ancha).
  horizontal,

  /// Burbujas apiladas de arriba a abajo (escena en retrato).
  vertical,
}

/// Tamaño lógico (dp) de la escena del widget. El launcher escala la imagen
/// al tamaño real del widget conservando la proporción (fitCenter), así el
/// diseño no se deforma al redimensionarlo.
///
/// Proporción 360×220 (~1.64:1): en un widget 2×2 casi cuadrado es la que
/// maximiza el tamaño de las burbujas en pantalla. Las burbujas se
/// dimensionan por el ANCHO (dos caben lado a lado), de modo que al encajar
/// la imagen el diámetro en el escritorio queda en ~0.44 del lado menor del
/// widget — casi el doble que con una escena ultraancha donde dominaba la
/// altura.
const Size kComparisonSceneSize = Size(360, 220);

/// Tamaño en retrato (220×360): el horizontal (360×220) girado, para el
/// widget estirado en vertical, con las burbujas apiladas una sobre la otra.
const Size kComparisonSceneVerticalSize = Size(220, 360);

/// Tamaño de la escena según la disposición elegida.
Size comparisonSceneSize(WidgetLayout layout) =>
    layout == WidgetLayout.vertical
        ? kComparisonSceneVerticalSize
        : kComparisonSceneSize;

/// Pinta la escena completa del widget de comparación (transparente): dos
/// burbujas — la mía y la del amigo — con su etiqueta debajo cada una,
/// lado a lado (horizontal) o apiladas (vertical). Es la misma composición
/// que `MoodSphereVisual`, rasterizable fuera del árbol de widgets para
/// obtener el PNG que muestra el AppWidget.
class MoodComparisonScenePainter extends CustomPainter {
  final DayBubbleData mine;
  final DayBubbleData friend;
  final String mineLabel;
  final String friendLabel;
  final WidgetLayout layout;

  const MoodComparisonScenePainter({
    required this.mine,
    required this.friend,
    required this.mineLabel,
    required this.friendLabel,
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
    final margin = size.width * 0.04;
    final gap = size.width * 0.033;
    final cellWidth = (size.width - 2 * margin - gap) / 2;

    final labelFont = size.height * 0.10;
    final labelTop = size.height - (labelFont * 1.55 + 6);
    // Las burbujas se dimensionan por el ANCHO: dos caben lado a lado y esa
    // es la cifra que manda al encajar la imagen en el widget (la escena
    // queda a lo ancho del escritorio, no a lo alto).
    final bubbleDiameter = size.width * 0.44;
    final bubbleCenterY = size.height * 0.42;

    final leftCenter = Offset(margin + cellWidth / 2, bubbleCenterY);
    final rightCenter = Offset(margin + cellWidth + gap + cellWidth / 2, bubbleCenterY);

    _paintBubble(canvas, Size(bubbleDiameter, bubbleDiameter), leftCenter, mine);
    _paintBubble(canvas, Size(bubbleDiameter, bubbleDiameter), rightCenter, friend);

    _paintLabel(canvas, leftCenter.dx, labelTop + (labelFont * 1.55 - labelFont) / 2, cellWidth, mineLabel, labelFont);
    _paintLabel(canvas, rightCenter.dx, labelTop + (labelFont * 1.55 - labelFont) / 2, cellWidth, friendLabel, labelFont);
  }

  void _paintVertical(Canvas canvas, Size size) {
    final margin = size.width * 0.04;
    // Las burbujas y etiquetas conservan el MISMO tamaño que en horizontal;
    // como el lienzo vertical es el horizontal girado (220×360), dos filas
    // apiladas no alcanzan a caber a tamaño completo: si desbordan, todo el
    // bloque (burbujas + etiquetas) se escala de forma uniforme para caber
    // con los márgenes. Así el look es idéntico, solo que el conjunto se
    // compacta si hace falta.
    var bubbleDiameter = kComparisonSceneSize.width * 0.44;
    var labelFont = kComparisonSceneSize.height * 0.10;
    final labelBand = labelFont * 1.6;
    final rowGap = kComparisonSceneVerticalSize.width * 0.08;
    var rowStep = bubbleDiameter + labelBand + rowGap;
    var total = 2 * rowStep;
    final available = size.height - 2 * margin;
    if (total > available) {
      final fit = available / total;
      bubbleDiameter *= fit;
      labelFont *= fit;
      rowStep *= fit;
      total *= fit;
    }
    final startY = math.max(margin, (size.height - total) / 2);
    final centerX = size.width / 2;

    for (var i = 0; i < 2; i++) {
      final y = startY + rowStep * i;
      final data = i == 0 ? mine : friend;
      final label = i == 0 ? mineLabel : friendLabel;
      _paintBubble(
          canvas,
          Size(bubbleDiameter, bubbleDiameter),
          Offset(centerX, y + bubbleDiameter / 2),
          data);
      final labelTop = y + bubbleDiameter + (labelBand - labelFont) / 2;
      _paintLabel(
          canvas, centerX, labelTop, size.width - 2 * margin, label, labelFont);
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
/// burbuja y se recorta a [maxRings]: con burbujas grandes (0.44 del ancho)
/// solo caben 2 anillos limpios entre el borde y la etiqueta de abajo.
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
/// de lo que queda en el escritorio. Se regenera cuando cambia tu burbuja,
/// la del amigo o la etiqueta.
class MoodComparisonScene extends StatefulWidget {
  final DayBubbleData mine;
  final DayBubbleData friend;
  final String mineLabel;
  final String friendLabel;
  final WidgetLayout layout;

  /// Tope de altura del recuadro de la preview. La escena mantiene su
  /// proporción real y se centra en el ancho disponible; el PNG rasterizado
  /// es idéntico (no cambia la resolución ni el dibujo). `null` deja que la
  /// preview ocupe todo el ancho (comportamiento previo).
  final double? maxHeight;

  const MoodComparisonScene({
    super.key,
    required this.mine,
    required this.friend,
    required this.mineLabel,
    required this.friendLabel,
    required this.layout,
    this.maxHeight,
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
    return [
      widget.layout,
      for (final c in widget.mine.colorsTopToBottom) c.toARGB32(),
      for (final c in widget.mine.auraColors) c.toARGB32(),
      for (final c in widget.friend.colorsTopToBottom) c.toARGB32(),
      for (final c in widget.friend.auraColors) c.toARGB32(),
      widget.friendLabel,
    ];
  }

  Future<void> _refreshPreview() async {
    if (_rendering) return;
    final sig = _makeSignature();
    if (_signature == sig && _png != null) return;
    _signature = sig;
    _rendering = true;
    try {
      final bytes = await renderComparisonScenePng(
        widget.mine,
        widget.friend,
        mineLabel: widget.mineLabel,
        friendLabel: widget.friendLabel,
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
    final preview = AspectRatio(
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
    final maxHeight = widget.maxHeight;
    if (maxHeight == null) return preview;
    // Preview compacta: se limita el alto (el ancho se deriva de la
    // proporción real) y se centra para no estirarse por toda la tarjeta.
    final width = maxHeight * (sceneSize.width / sceneSize.height);
    return Center(
      child: SizedBox(width: width, height: maxHeight, child: preview),
    );
  }
}

/// Rasteriza la escena fuera del árbol de widgets y la devuelve como PNG en
/// bytes. El [pixelRatio] sube la resolución para que en pantallas con
/// densidad alta no se vea pixelada.
Future<Uint8List> renderComparisonScenePng(
  DayBubbleData mine,
  DayBubbleData friend, {
  String mineLabel = 'Yo',
  required String friendLabel,
  required WidgetLayout layout,
  double pixelRatio = 2,
}) async {
  final sceneSize = comparisonSceneSize(layout);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  MoodComparisonScenePainter(
    mine: mine,
    friend: friend,
    mineLabel: mineLabel,
    friendLabel: friendLabel,
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