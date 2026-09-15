import 'package:flutter/material.dart';

import '../../features/friends/profiles_pager_screen.dart';

/// Controlador de navegación del pager raíz (`ProfilesPagerScreen`): la
/// píldora del hub y la hoja de amigos navegan por él en vez de empujar
/// rutas, así el usuario puede volver al Home deslizando.
///
/// Lo construye `_AppFrame` y lo expone vía [FriendsPagerScope] POR ENCIMA
/// del Navigator (igual que el hub), porque la píldora y las rutas empujadas
/// viven por debajo y necesitan alcanzarlo.
class FriendsPagerController {
  FriendsPagerController({required this.navigatorKey});

  /// Navigator del `MaterialApp` (para limpiar rutas empujadas al volver al
  /// inicio) y clave del estado del pager (para saltar de perfil).
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ProfilesPagerScreenState> pagerKey =
      GlobalKey<ProfilesPagerScreenState>();

  /// Vuelve a la página 0 (el Home real) y limpia cualquier ruta empujada
  /// (historial, estados, ajustes...) estés donde estés dentro del Navigator.
  /// Las rutas se limpian PRIMERO y el pager se mueve en el frame siguiente:
  /// cubierto por rutas empujadas su viewport queda en 0 y `animateToPage`
  /// no podría moverse (ni congelarse queriendo avanzar).
  void goHome() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pagerKey.currentState?.goHome();
    });
  }

  /// Salta al perfil de un amigo (por id) dentro del pager. Igual que
  /// `goHome`: primero despeja las rutas empujadas y recién en el frame
  /// siguiente anima el pager (ya visible y medido). El pager se encarga de
  /// remarcar la selección en la píldora al asentarse.
  void jumpToProfile(String friendId) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pagerKey.currentState?.jumpToProfile(friendId);
    });
  }
}

/// Expone el [FriendsPagerController] a todo lo que está por debajo del
/// Navigator (páginas del pager, hoja de amigos, la píldora).
class FriendsPagerScope extends InheritedWidget {
  const FriendsPagerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final FriendsPagerController controller;

  /// Lectura pura (sin registrar dependencia de rebuild): el controlador se
  /// alcanza desde callbacks de gestos (píldora/hoja), no desde build.
  static FriendsPagerController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FriendsPagerScope>()?.controller;

  static FriendsPagerController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No hay FriendsPagerScope en el árbol.');
    return controller!;
  }

  @override
  bool updateShouldNotify(FriendsPagerScope oldWidget) =>
      oldWidget.controller != controller;
}