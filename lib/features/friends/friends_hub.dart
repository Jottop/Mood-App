import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/friends_pill_scope.dart';
import '../../data/models/profile.dart';
import '../../data/pill_capsule_prefs.dart';
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
/// La píldora es arrastrable (mantener presionado y mover): mientras se
/// arrastra ROTA EN VIVO —vertical si te acercas a un costado, horizontal si
/// estás centrado— y al soltarla se adhiere al margen izquierdo o derecho
/// (vertical, con altura libre) o vuelve al centro inferior (horizontal) si
/// se suelta centrada. La posición se guarda solo en el dispositivo.
class FriendsHubOverlay extends StatefulWidget {
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  const FriendsHubOverlay(
      {super.key, required this.navigator, required this.child});

  @override
  State<FriendsHubOverlay> createState() => _FriendsHubOverlayState();
}

class _FriendsHubOverlayState extends State<FriendsHubOverlay> {
  static const _hInset = 12.0;
  static const _vInset = 10.0;
  static const _storageKey = 'friends_pill_position';

  // Estimación de tamaño vertical (hasta que se mide la píldora real).
  static const _vWidth = 52.0;

  final _pillKey = GlobalKey();

  _PillEdge _edge = _PillEdge.center;
  double _fraction = 0;
  Offset _drag = Offset.zero;
  bool _dragging = false;
  // Tamaño real medido POR ORIENTACIÓN: la píldora rota en vivo según el
  // arrastre (vertical sobre un costado, horizontal centrada) y cada forma
  // tiene sus propias dimensiones.
  Size _hPillSize = Size.zero;
  Size _vPillSize = Size.zero;
  // Orientación mostrada MOMENTÁNEAMENTE durante el arrastre. Con histéresis:
  // una vez vertical solo vuelve a horizontal al pasar por la zona céntrica,
  // y una vez horizontal solo rota al acercarse bien a un borde. Así el
  // cambio de ancho al rotar no rebota el umbral en bucle.
  bool _previewVertical = false;

  // Geometría actual de la píldora, publicada para que los avisos y el FAB
  // de abajo se reposicionen sin taparse con ella (null si está oculta).
  final ValueNotifier<Rect?> _pillRect = ValueNotifier<Rect?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());
    _loadPosition();
    // Fondo de la cápsula guardado en este dispositivo (color SOLO local).
    loadPillCapsuleBg();
  }

  @override
  void dispose() {
    _pillRect.dispose();
    super.dispose();
  }

  /// Publica el rect de la píldora (o null si está oculta) solo cuando
  /// cambia, para no notificar dependientes en cada frame.
  void _publishPillRect(Rect? rect) {
    if (_pillRect.value != rect) _pillRect.value = rect;
  }

  /// Orientación vigente: la del arrastre si estás moviendo, la del anclaje
  /// guardado si estás quieto.
  bool get _vertical =>
      _dragging ? _previewVertical : _edge != _PillEdge.center;

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

  /// Guarda el tamaño medido de la píldora EN SU ORIENTACIÓN ACTUAL (se
  /// ejecuta todos los frames; el tamaño apenas cambia y el guardado es
  /// barato).
  void _measurePill() {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    final target = _vertical ? _vPillSize : _hPillSize;
    if (size != target && mounted) {
      setState(() {
        if (_vertical) {
          _vPillSize = size;
        } else {
          _hPillSize = size;
        }
      });
    }
  }

  /// Dimensiones de la orientación pedida: la medida real si existe, si no,
  /// la estimación (evita usar el tamaño de la otra orientación al rotar).
  Size _sizeFor(bool vertical) {
    final s = vertical ? _vPillSize : _hPillSize;
    if (s.width > 0 && s.height > 0) return s;
    if (vertical) {
      return Size(_vWidth, _estimatedVerticalHeight());
    }
    return const Size(240, 54);
  }

  /// Alto aproximado de la píldora vertical: círculos (me + amigos + chip +N
  /// + botón "+"), los separadores entre ellos y el padding del contenedor.
  double _estimatedVerticalHeight() {
    final count = context.read<FriendsProvider>().friends.length;
    final visible = math.min(count, FriendsHubPill.maxFriends);
    final items = 1 + visible + (count > FriendsHubPill.maxFriends ? 1 : 0) + 1;
    final gaps = math.max(0, visible - 1) +
        (count > FriendsHubPill.maxFriends ? 1 : 0) +
        1;
    return 24 + items * 34.0 + gaps * 7.0 + 19.0;
  }

  /// Orientación que se MANTENDRÁ (histéresis) según la posición horizontal
  /// al arrastrar el dedo. `cx` es el centro X de la píldora.
  bool _nextPreviewVertical(double cx, double screenW) {
    final mid = screenW / 2;
    final c = cx / screenW;
    final inCenter = (cx - mid).abs() < screenW * 0.14;
    if (_previewVertical) return !inCenter;
    return c <= 0.28 || c >= 0.72;
  }

  /// Actualiza el arrastre y en el mismo pase decide si la píldora debe
  /// verse vertical (costados) u horizontal (resto).
  void _onDragMove(Size screen, double topInset, double bottomInset,
      double bandTop, Offset newDrag) {
    final s = _sizeFor(_previewVertical);
    final w = s.width;
    final h = s.height;
    final bandHeight =
        math.max(0.0, screen.height - topInset - bottomInset - _vInset * 2 - h);
    final base =
        _baseOffset(screen, topInset, bottomInset, bandTop, bandHeight, w, h);
    final maxLeft = math.max(_hInset, screen.width - w - _hInset);
    final left = (base.dx + newDrag.dx).clamp(_hInset, maxLeft);
    final cx = left + w / 2;
    final nextVertical = _nextPreviewVertical(cx, screen.width);
    if (nextVertical != _previewVertical || newDrag != _drag) {
      setState(() {
        _drag = newDrag;
        _previewVertical = nextVertical;
      });
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
        return Offset(
            screen.width - _hInset - w, bandTop + bandHeight * _fraction);
    }
  }

  /// Al soltar el arrastre: recalcula el margen (izquierda/derecha o centro
  /// inferior), la orientación (vertical en el costado, horizontal al centro)
  /// y la altura vertical, y persiste la posición.
  void _releaseDrag(Size screen, double topInset, double bottomInset,
      double bandTop, double bandHeight, double w, double h) {
    if (!mounted) return;
    final base =
        _baseOffset(screen, topInset, bottomInset, bandTop, bandHeight, w, h);
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
      // La fracción se mide contra la banda de la ORIENTACIÓN DESTINO
      // (vertical): así al rotar al soltar la píldora no salta de lugar.
      final targetH = _sizeFor(true).height;
      final targetBand = math.max(
          0.0, screen.height - topInset - bottomInset - _vInset * 2 - targetH);
      newFraction =
          targetBand <= 0 ? 0.0 : ((fy - bandTop) / targetBand).clamp(0.0, 1.0);
    }

    setState(() {
      _dragging = false;
      _drag = Offset.zero;
      _edge = newEdge;
      _fraction = newFraction;
      _previewVertical = newEdge != _PillEdge.center;
    });
    _savePosition();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(builder: (context, constraints) {
      if (keyboardOpen) {
        _publishPillRect(null);
        return FriendsPillScope(
          notifier: _pillRect,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(child: widget.child),
            ],
          ),
        );
      }

      final screen = constraints.biggest;
      final topInset = MediaQuery.paddingOf(context).top;
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      final vertical = _vertical;
      final s = _sizeFor(vertical);
      final w = s.width;
      final h = s.height;
      final bandTop = topInset + _vInset;
      final bandHeight = math.max(
          0.0, screen.height - topInset - bottomInset - _vInset * 2 - h);

      final base =
          _baseOffset(screen, topInset, bottomInset, bandTop, bandHeight, w, h);
      final maxLeft = math.max(_hInset, screen.width - w - _hInset);
      final maxTop = math.max(bandTop, bandTop + bandHeight);
      final left = (base.dx + _drag.dx).clamp(_hInset, maxLeft);
      final top = (base.dy + _drag.dy).clamp(bandTop, maxTop);

      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());
      _publishPillRect(Rect.fromLTWH(left, top, w, h));

      return FriendsPillScope(
        notifier: _pillRect,
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            Positioned.fill(child: widget.child),
            // AnimatedPositioned arranca en cero mientras arrastras (sigue
            // el dedo) y hace un pequeño "dock" animado al soltar en un
            // borde o volver al centro.
            AnimatedPositioned(
              duration:
                  _dragging ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              left: left,
              top: top,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (_) => setState(() {
                  _dragging = true;
                  _previewVertical = _edge != _PillEdge.center;
                }),
                onLongPressMoveUpdate: (details) => _onDragMove(screen,
                    topInset, bottomInset, bandTop, details.offsetFromOrigin),
                onLongPressEnd: (_) => _releaseDrag(
                    screen, topInset, bottomInset, bandTop, bandHeight, w, h),
                onLongPressCancel: () => setState(() {
                  _dragging = false;
                  _drag = Offset.zero;
                }),
                child: Transform.scale(
                  scale: _dragging ? 1.04 : 1.0,
                  child: FriendsHubPill(
                    key: _pillKey,
                    navigator: widget.navigator,
                    vertical: vertical,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// La píldora flotante: mi avatar, los amigos (hasta un tope) y el botón
/// "+" para copiar el código, agregar por código o quitar amigos. En
/// [vertical] apila el contenido en una columna (se usa al anclarla a un
/// costado de la pantalla).
class FriendsHubPill extends StatelessWidget {
  static const maxFriends = 4;

  final GlobalKey<NavigatorState> navigator;
  final bool vertical;

  const FriendsHubPill({
    super.key,
    required this.navigator,
    this.vertical = false,
  });

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

    // Espaciado en el eje cruzado (9 alrededor del separador, 7 entre el
    // resto de círculos) y el separador transpuesto según la orientación.
    Widget gap(double v) => vertical ? SizedBox(height: v) : SizedBox(width: v);

    final children = <Widget>[
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
      gap(9),
      // Separador sutil entre mi icono y el resto de la píldora.
      Container(
        width: vertical ? 22 : 1,
        height: vertical ? 1 : 22,
        color: AppColors.ink.withValues(alpha: 0.14),
      ),
      gap(9),
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
        if (friend != visibleFriends.last) gap(7),
      ],
      if (overflow > 0) ...[
        gap(7),
        _OverflowChip(navigator: navigator, count: overflow),
      ],
      gap(7),
      _AddButton(navigator: navigator),
    ];

    return ValueListenableBuilder<Color>(
      valueListenable: pillCapsuleBg,
      builder: (context, capsuleBg, _) => Container(
        padding: vertical
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: capsuleBg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: children)
            : Row(mainAxisSize: MainAxisSize.min, children: children),
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
