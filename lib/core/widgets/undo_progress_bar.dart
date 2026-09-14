import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra que se vacía durante [UndoProgressBar.duration] mientras el aviso de
/// "Eliminado"/"Emoción eliminada" está visible: la medida del tiempo que
/// queda para que el borrado sea definitivo (o se pulse "Deshacer"). Al
/// completarse avisa con [onFinished] (cierre garantizado del aviso, porque
/// un SnackBar con acción no se cierra solo en Flutter).
class UndoProgressBar extends StatefulWidget {
  final Duration duration;
  final VoidCallback onFinished;

  /// Texto del aviso que acompaña a la barra.
  final String label;

  const UndoProgressBar({
    super.key,
    required this.duration,
    required this.onFinished,
    this.label = 'Registro eliminado',
  });

  @override
  State<UndoProgressBar> createState() => _UndoProgressBarState();
}

class _UndoProgressBarState extends State<UndoProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra horizontal que se va acabando (1 → 0) en la duración
            // total del aviso.
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 1 - _controller.value,
                minHeight: 4,
                color: AppColors.ink,
                backgroundColor: AppColors.cardLine,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ],
        );
      },
    );
  }
}