import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

const _rainbowColors = <Color>[
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

/// Abre el selector de color personalizado: recuadro saturación/valor
/// (la "caja con todos los colores") + barra de tonos y campo HEX editable.
/// Devuelve el color elegido, o `null` si el usuario cancela.
Future<Color?> showCustomColorPicker(BuildContext context, {required Color initialColor}) {
  return showDialog<Color>(
    context: context,
    // El teclado del sistema no debe reacomodar el diálogo: poniendo
    // `viewInsets` a cero, el `AnimatedPadding` interno del `Dialog` no suma
    // el espacio del teclado y el menú queda fijo en su lugar (el teclado
    // simplemente lo cubre). Eso evita el reflow/bucle de layout con el IME
    // que congelaba la app en algunos teléfonos.
    builder: (dialogContext) => MediaQuery(
      data: MediaQuery.of(dialogContext).copyWith(viewInsets: EdgeInsets.zero),
      child: _CustomColorPickerDialog(initialColor: initialColor),
    ),
  );
}

class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _CustomColorPickerDialog({required this.initialColor});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  static final _hexPattern = RegExp(r'^[0-9a-fA-F]{6}$');
  static final _hexFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]'));

  late HSVColor _current;
  late final TextEditingController _hexController;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _current = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _hexOf(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  /// `#RRGGBB` en mayúsculas del color indicado.
  static String _hexOf(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Aplica un código HEX (con o sin `#`) si es válido de 6 dígitos.
  void _applyHex(String raw) {
    final hex = raw.replaceAll('#', '').replaceAll(' ', '').trim();
    if (!_hexPattern.hasMatch(hex)) return;
    final color = Color(0xFF000000 | int.parse(hex, radix: 16));
    if (color.toARGB32() == _current.toColor().toARGB32()) return;
    setState(() => _current = HSVColor.fromColor(color));
  }

  /// Refleja el color actual en el campo HEX (sin pisar lo que el usuario
  /// está escribiendo a medias).
  void _syncHexText() {
    final text = _hexOf(_current.toColor());
    if (_hexController.text != text) _hexController.text = text;
    if (!_hexController.selection.isValid) {
      _hexController.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  /// Copia el código HEX al portapapeles y muestra una breve confirmación.
  Future<void> _copyHex() async {
    await Clipboard.setData(ClipboardData(text: _hexOf(_current.toColor())));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Color personalizado'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vista previa del color actual + campo para pegar/escribir un
            // código HEX propio, con botón de copiar.
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _current.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    maxLength: 7,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    inputFormatters: [_hexFormatter],
                    onChanged: _applyHex,
                    decoration: InputDecoration(
                      hintText: '#RRGGBB',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.card,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Copiar código HEX',
                        iconSize: 20,
                        color: AppColors.inkSoft,
                        icon: Icon(_copied ? Icons.check_rounded : Icons.copy_all_rounded),
                        onPressed: _copyHex,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 260,
                height: 220,
                child: _SaturationValueBox(
                  current: _current,
                  onChanged: (saturation, value) => setState(() {
                    _current = _current.withSaturation(saturation).withValue(value);
                    _syncHexText();
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _HueBar(
              hue: _current.hue,
              onHueChanged: (hue) => setState(() {
                _current = _current.withHue(hue);
                _syncHexText();
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_current.toColor()),
          child: const Text('Usar color'),
        ),
      ],
    );
  }
}

/// Recuadro de saturación (eje X) y valor/luminosidad (eje Y) para un tono
/// fijo. El indicador sigue el dedo: `HSVColor.fromAHSV`.
class _SaturationValueBox extends StatelessWidget {
  final HSVColor current;
  final void Function(double saturation, double value) onChanged;

  const _SaturationValueBox({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, current.hue, 1, 1).toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Saturacion izquierda a derecha.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, hueColor],
                    ),
                  ),
                ),
                // Valor arriba a abajo (negro abajo = valor 0).
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
                _buildIndicator(size),
              ],
            ),
          ),
        );
      },
    );
  }

  void _update(Offset pos, Size size) {
    final saturation = (pos.dx / size.width).clamp(0.0, 1.0);
    final value = 1.0 - (pos.dy / size.height).clamp(0.0, 1.0);
    onChanged(saturation.toDouble(), value.toDouble());
  }

  Widget _buildIndicator(Size size) {
    const radius = 13.0;
    final dx = current.saturation * size.width;
    final dy = (1 - current.value) * size.height;
    return Positioned(
      left: dx - radius,
      top: dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current.toColor(),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/// Barra de tonos arcoíris (0–360°) con pulgar arrastrable.
class _HueBar extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onHueChanged;

  const _HueBar({required this.hue, required this.onHueChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (d) => onHueChanged(d.localPosition.dx / width * 360),
          onPanUpdate: (d) => onHueChanged((d.localPosition.dx / width * 360).clamp(0, 360)),
          child: RepaintBoundary(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: _rainbowColors),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: (hue / 360 * width).clamp(13.0, width - 13),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}