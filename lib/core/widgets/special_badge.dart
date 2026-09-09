import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// La marca de "emoción especial": el ícono de radar (anillos concéntricos,
/// igual al aura que rodea a la burbuja) suelto, tal como se muestra junto
/// al nombre en la lista de gestión de estados. Se superpone a avatares,
/// burbujas o etiquetas para indicar de un vistazo que el estado es
/// especial, en cualquier parte donde se vea.
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
    return Icon(Icons.radar, size: size, color: color);
  }
}