import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'friends_pill_scope.dart';

/// Margen inferior (px desde el canto inferior de la pantalla, incluyendo el
/// padding de la barra de sistema) que necesita un aviso para no taparse con
/// la píldora flotante de amigos.
///
/// Si la píldora está en la zona baja de la pantalla (lo típico: centrada o
/// anclada a un costado abajo), el aviso se eleva justo por encima de su
/// tope; si está anclada alta en un costado no estorba y se usa [minimum].
/// [minimum] reserva además otros obstáculos fijos (p. ej. un FAB).
double bottomReserveFor(BuildContext context, {double minimum = 12}) {
  final size = MediaQuery.sizeOf(context);
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  var reserve = minimum;
  final pill = FriendsPillScope.rectOf(context);
  // Solo estorba si su canto inferior cayó en la zona baja (>72% del alto).
  if (pill != null && pill.bottom >= size.height * 0.72) {
    reserve = math.max(reserve, (size.height - pill.top) + 12);
  }
  return bottomPadding + reserve;
}

/// Margen inferior del FAB (px desde el canto inferior de la pantalla) para
/// que el botón nunca quede pegado a la píldora. Respeta el tope mínimo
/// habitual [minimum] y solo se eleva si la píldora baja sobre la zona del
/// FAB (píldora centrada o anclada al borde derecho, que es donde vive).
double fabReserveFor(BuildContext context, {double minimum = 80}) {
  final size = MediaQuery.sizeOf(context);
  var reserve = minimum;
  final pill = FriendsPillScope.rectOf(context);
  if (pill != null && pill.bottom >= size.height * 0.72) {
    // El FAB extendido queda a la derecha, a ~16px del borde.
    const fabWidth = 200.0;
    final fabLeft = size.width - 16 - fabWidth;
    final overlapsWidth =
        pill.right >= fabLeft && pill.left <= size.width - 16;
    if (overlapsWidth) {
      reserve = math.max(reserve, (size.height - pill.top) + 12);
    }
  }
  return reserve;
}

/// Muestra un aviso flotante con el estilo unificado de la app (píldora
/// clara, redondeada), reposicionado para no chocar con la píldora de amigos
/// ni con el FAB (vía [minimum]).
///
/// Reemplaza a `ScaffoldMessenger.showSnackBar` directo en toda la app: el
/// margen inferior se calcula con [bottomReserveFor] en el momento de
/// mostrarse.
void showAppSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  double minimum = 12,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomReserveFor(context, minimum: minimum),
        ),
        // Píldora clara (no opaca) para que no tape la lista de debajo.
        backgroundColor: AppColors.card,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardLine),
        ),
        // Fondo claro propio: el texto no debe heredar el color por defecto
        // de M3 (diseñado para fondo oscuro), sino el tinta de la app.
        content: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.ink),
          child: content,
        ),
        duration: duration,
        action: action,
      ),
    );
}