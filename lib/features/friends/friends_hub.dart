import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar.dart';
import '../../data/models/profile.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';
import 'friend_profile_screen.dart';
import 'friends_sheet.dart';

enum _PillEdge { center, left, right }

/// Overlay global (por encima del Navigator) que muestra la píldora flotante
/// del hub de amigos: mi avatar, hasta [FriendsHubPill.maxFriends] amigos y
/// el botón "+". Se oculta mientras el teclado está abierto para no tapar
/// los campos de texto.
///
/// La píldora es arrastrable (mantener presionado y mover): al soltarla se
/// adhiere al margen izquierdo o derecho (con altura libre) o vuelve al
/// centro inferior si se suelta centrada. La posición se guarda solo en el
/// dispositivo.
class FriendsHubOverlay extends StatefulWidget {
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  const FriendsHubOverlay({super.key, required this.navigator, required this.child});

  @override
  State<FriendsHubOverlay> createState() => _FriendsHubOverlayState();
}

class _FriendsHubOverlayState extends State<FriendsHubOverlay> {
  static const _hInset = 12.0;
  static const _vInset = 10.0;
  static const _storageKey = 'friends_pill_position';

  final _pillKey = GlobalKey();

  _PillEdge _edge = _PillEdge.center;
  double _fraction = 0;
  Offset _drag = Offset.zero;
  bool _dragging = false;
  Size _pillSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());
    _loadPosition();
  }

  /// Recupera la posición guardada en este dispositivo.
  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    if (raw == 'center') {
      if (mounted) {
        setState(() => _edge = _PillEdge.center);
      }
      return;
    }
    final parts = raw.split(':');
    if (parts.length != 2) return;
    final edge = parts[0] == 'right' ? _PillEdge.right : _PillEdge.left;
    final fraction = (double.tryParse(parts[1]) ?? 0).clamp(0.0, 1.0);
    if (!mounted) return;
    setState(() {
      _edge = edge;
      _fraction = fraction;
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final value = _edge == _PillEdge.center
        ? 'center'
        : '${_edge == _PillEdge.right ? 'right' : 'left'}:${_fraction.toStringAsFixed(3)}';
    await prefs.setString(_storageKey, value);
  }

  /// Mide la píldora real para posicionarla con precisión (se ejecuta todos
  /// los frames; el tamaño apenas cambia y el guardado es barato).
  void _measurePill() {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size != _pillSize && mounted) {
      setState(() => _pillSize = size);
    }
  }

  Offset _baseOffset(Size screen, double topInset, double bottomInset,
      double bandTop, double bandHeight, double w, double h) {
    switch (_edge) {
      case _PillEdge.center:
        return Offset(
          (screen.width - w) / 2,
          screen.height - bottomInset - _vInset - h,
        );
      case _PillEdge.left:
        return Offset(_hInset, bandTop + bandHeight * _fraction);
      case _PillEdge.right:
        return Offset(screen.width - _hInset - w, bandTop + bandHeight * _fraction);
    }
  }

  /// Al soltar el arrastre: recalcula el margen (izquierda/derecha o centro
  /// inferior) y la altura vertical, y persiste la posición.
  void _releaseDrag(
      Size screen, double topInset, double bottomInset, double bandTop,
      double bandHeight, double w, double h) {
    if (!mounted) return;
    final base = _baseOffset(screen, topInset, bottomInset, bandTop, bandHeight, w, h);
    final maxLeft = math.max(_hInset, screen.width - w - _hInset);
    final fx = (base.dx + _drag.dx).clamp(_hInset, maxLeft);
    final maxTop = math.max(bandTop, bandTop + bandHeight);
    final fy = (base.dy + _drag.dy).clamp(bandTop, maxTop);

    final cx = fx + w / 2;
    final mid = screen.width / 2;
    // Zona "centrada" chica (~10% de la pantalla): si se suelta lejos del
    // centro se ancla al margen izquierdo o derecho. Antes se comparaba
    // contra el ancho completo de la píldora y casi nunca salía de esa zona
    // en un teléfono, así que el arrastre "volvía" siempre al centro.
    final centered = (cx - mid).abs() < screen.width * 0.1;

    _PillEdge newEdge;
    var newFraction = _fraction;
    if (centered) {
      newEdge = _PillEdge.center;
    } else {
      newEdge = cx < mid ? _PillEdge.left : _PillEdge.right;
      newFraction =
          bandHeight <= 0 ? 0.0 : ((fy - bandTop) / bandHeight).clamp(0.0, 1.0);
    }

    setState(() {
      _dragging = false;
      _drag = Offset.zero;
      _edge = newEdge;
      _fraction = newFraction;
    });
    _savePosition();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(builder: (context, constraints) {
      if (keyboardOpen) {
        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            Positioned.fill(child: widget.child),
          ],
        );
      }

      final screen = constraints.biggest;
      final topInset = MediaQuery.paddingOf(context).top;
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      final w = _pillSize.width > 0 ? _pillSize.width : 240.0;
      final h = _pillSize.height > 0 ? _pillSize.height : 54.0;
      final bandTop = topInset + _vInset;
      final bandHeight = math.max(
          0.0, screen.height - topInset - bottomInset - _vInset * 2 - h);

      final base = _baseOffset(screen, topInset, bottomInset, bandTop, bandHeight, w, h);
      final maxLeft = math.max(_hInset, screen.width - w - _hInset);
      final maxTop = math.max(bandTop, bandTop + bandHeight);
      final left = (base.dx + _drag.dx).clamp(_hInset, maxLeft);
      final top = (base.dy + _drag.dy).clamp(bandTop, maxTop);

      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());

      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (_) => setState(() => _dragging = true),
              onLongPressMoveUpdate: (details) =>
                  setState(() => _drag = details.offsetFromOrigin),
              onLongPressEnd: (_) =>
                  _releaseDrag(screen, topInset, bottomInset, bandTop, bandHeight, w, h),
              onLongPressCancel: () => setState(() {
                _dragging = false;
                _drag = Offset.zero;
              }),
              child: Transform.scale(
                scale: _dragging ? 1.04 : 1.0,
                child: FriendsHubPill(key: _pillKey, navigator: widget.navigator),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// La píldora flotante: mi avatar, los amigos (hasta un tope) y el botón
/// "+" para copiar el código, agregar por código o quitar amigos.
class FriendsHubPill extends StatelessWidget {
  static const maxFriends = 4;

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
          AvatarBadge(
            background: myProfile?.pillBg ?? AppColors.cream,
            foreground: myProfile?.pillFg ?? AppColors.creamInk,
            avatar: myProfile?.avatar,
            initial: myProfile?.displayInitial ?? '?',
            selected: isMeSelected,
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
            AvatarBadge(
              background: friend.pillBg,
              foreground: friend.pillFg,
              avatar: friend.avatar,
              initial: friend.displayInitial,
              selected: selectedProfileId == friend.id,
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