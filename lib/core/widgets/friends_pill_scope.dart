import 'package:flutter/material.dart';

/// Expone la geometría actual de la píldora flotante del hub de amigos para
/// que los avisos (SnackBar) y los elementos anclados abajo (FAB) puedan
/// reposicionarse y nunca quedar tapados por ella.
///
/// Lo provee `FriendsHubOverlay` (que vive POR ENCIMA del Navigator) y lo
/// leen las pantallas que están por debajo. El [notifier] guarda el `Rect`
/// de la píldora en coordenadas de pantalla, o null si está oculta (teclado
/// abierto o aún no medida).
class FriendsPillScope extends InheritedNotifier<ValueNotifier<Rect?>> {
  const FriendsPillScope({
    super.key,
    required ValueNotifier<Rect?> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// Lee el scope y se suscribe a sus cambios (rebuild al mover la píldora).
  static FriendsPillScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FriendsPillScope>();

  /// `Rect` actual de la píldora, o null si está oculta o no hay hub.
  static Rect? rectOf(BuildContext context) =>
      maybeOf(context)?.notifier?.value;
}