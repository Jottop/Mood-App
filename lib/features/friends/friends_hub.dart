import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/profile.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';
import 'friend_profile_screen.dart';
import 'friends_sheet.dart';

/// Overlay global (por encima del Navigator) que muestra la píldora flotante
/// del hub de amigos: mi avatar, hasta [FriendsHubPill.maxFriends] amigos y
/// el botón "+". Se oculta mientras el teclado está abierto para no tapar
/// los campos de texto.
class FriendsHubOverlay extends StatelessWidget {
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  const FriendsHubOverlay({super.key, required this.navigator, required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: child),
        if (!keyboardOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 10),
              child: Center(child: FriendsHubPill(navigator: navigator)),
            ),
          ),
      ],
    );
  }
}

/// La píldora flotante: mi avatar, los amigos (hasta un tope) y el botón
/// "+" para copiar el código, agregar por código o quitar amigos.
class FriendsHubPill extends StatelessWidget {
  static const maxFriends = 4;

  static const _friendPalette = <Color>[
    Color(0xFFD9E9FA),
    Color(0xFFE3F5E6),
    Color(0xFFFCEBD8),
    Color(0xFFEFE6FB),
    Color(0xFFFBE0EA),
  ];

  final GlobalKey<NavigatorState> navigator;

  const FriendsHubPill({super.key, required this.navigator});

  @override
  Widget build(BuildContext context) {
    final myProfile = context.watch<AuthProvider>().profile;
    final friendsProvider = context.watch<FriendsProvider>();
    final friends = friendsProvider.friends;
    final selectedProfileId = friendsProvider.selectedProfileId;

    final visibleFriends = friends.take(maxFriends).toList();
    final overflow = friends.length - visibleFriends.length;
    // En el Home (sin perfil de amigo a la vista) se remarca mi icono.
    final isMeSelected = selectedProfileId == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(
            label: myProfile?.username ?? '?',
            background: AppColors.cream,
            foreground: AppColors.creamInk,
            isSelected: isMeSelected,
            onTap: () {
              // La selección se ajusta DESDE el gesto (antes de navegar), no
              // desde el ciclo de vida del route: notificar dentro de
              // initState/dispose de la pantalla congela la app porque la
              // píldora está por encima del Navigator y se reconstruye en el
              // mismo pase de build.
              friendsProvider.selectProfile(null);
              _goHome();
            },
            tooltip: 'Ir al inicio',
          ),
          const SizedBox(width: 9),
          // Separador sutil entre mi icono y el resto de la píldora.
          Container(
            width: 1,
            height: 22,
            color: AppColors.ink.withValues(alpha: 0.14),
          ),
          const SizedBox(width: 9),
          for (final friend in visibleFriends) ...[
            _Avatar(
              label: friend.username,
              background: _colorFor(friend.username),
              foreground: AppColors.ink,
              isSelected: selectedProfileId == friend.id,
              onTap: () {
                friendsProvider.selectProfile(friend.id);
                _openFriend(friend);
              },
              tooltip: friend.displayName,
            ),
            if (friend != visibleFriends.last) const SizedBox(width: 7),
          ],
          if (overflow > 0) ...[
            const SizedBox(width: 7),
            _OverflowChip(navigator: navigator, count: overflow),
          ],
          const SizedBox(width: 7),
          _AddButton(navigator: navigator),
        ],
      ),
    );
  }

  static Color _colorFor(String username) {
    final hash =
        username.codeUnits.fold<int>(0, (acc, u) => (acc * 31 + u) & 0x7fffffff);
    return _friendPalette[hash % _friendPalette.length];
  }

  /// Mi avatar: vuelve al inicio (el menú principal del día, el Home),
  /// estés donde estés dentro del Navigator.
  void _goHome() {
    navigator.currentState?.popUntil((route) => route.isFirst);
  }

  void _openFriend(Profile friend) {
    navigator.currentState?.push(
      MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: friend)),
    );
  }
}

/// Avatar circular con la inicial del usuario. El que corresponde al perfil
/// seleccionado (el que se está viendo) lleva un anillo; el resto no.
class _Avatar extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _Avatar({
    required this.label,
    required this.background,
    required this.foreground,
    this.isSelected = false,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label[0].toUpperCase();
    // Semantics en lugar de Tooltip: la píldora vive POR ENCIMA del
    // Navigator (MaterialApp.builder), donde no hay Overlay y Tooltip crashea.
    return Semantics(
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            // Siempre el mismo ancho de borde (transparente si no está
            // seleccionado) para que el anillo no cambie el tamaño al
            // seleccionar.
            border: Border.all(
              color: isSelected ? AppColors.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: foreground,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip con los amigos sobrantes ("+N"): abre la hoja con la lista completa.
class _OverflowChip extends StatelessWidget {
  final GlobalKey<NavigatorState> navigator;
  final int count;

  const _OverflowChip({required this.navigator, required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ver todos mis amigos',
      child: GestureDetector(
        onTap: () => showFriendsSheet(navigator, onlyList: true),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cream,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardLine),
          ),
          child: Text(
            '+$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.creamInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "+": abre la hoja completa (código + agregar + quitar).
class _AddButton extends StatelessWidget {
  final GlobalKey<NavigatorState> navigator;

  const _AddButton({required this.navigator});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Agregar amigos',
      child: GestureDetector(
        onTap: () => showFriendsSheet(navigator, onlyList: false),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}