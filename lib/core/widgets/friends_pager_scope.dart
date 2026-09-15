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
  void goHome() {
    pagerKey.currentState?.goHome();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Salta al perfil de un amigo (por id) dentro del pager. El pager se
  /// encarga de remarcar la selección en la píldora al asentarse.
  void jumpToProfile(String friendId) {
    pagerKey.currentState?.jumpToProfile(friendId);
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