import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// La marca de "emoción especial": una chincheta (pushpin), que evoca algo
/// fijado y destacado de un vistazo. Se superpone a avatares, burbujas o
/// etiquetas para indicar que el estado es especial, en cualquier parte
/// donde se vea.
class SpecialBadge extends StatelessWidget {
  final double size;
  final Color color;

  const SpecialBadge({
    super.key,
    this.size = 15,
    this.color = AppColors.inkSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.push_pin_rounded, size: size, color: color);
  }
}