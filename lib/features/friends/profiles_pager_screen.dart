import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/profile.dart';
import '../../state/friends_provider.dart';
import '../home/home_screen.dart';
import 'friend_profile_page.dart';

/// Pager raíz de la app con sesión: el Home real es la página 0 y cada amigo
/// una página más ([Home, amigo1, ..., amigoN]). Se llega de un perfil al
/// otro deslizando horizontalmente, con la MISMA mecánica exacta que el
/// detalle de días (`DayDetailScreen`): el pager usa SOLO 3 páginas alrededor
/// del perfil visible (anterior / actual / siguiente) y al asentarse el
/// scroll rebasa a la página central. El offset nunca crece (cada gesto
/// avanza una sola página, controlado) y en los bordes —por la izquierda el
/// Home, por la derecha el último amigo— el swipe rebota.
///
/// La navegación externa (píldora del hub, hoja de amigos) salta
/// programáticamente por la misma ventana: va avanzando de uno en uno por el
/// [PageController] para que recorrer varios perfiles se sienta como
/// deslizarse hacia ellos.
class ProfilesPagerScreen extends StatefulWidget {
  const ProfilesPagerScreen({super.key});

  @override
  State<ProfilesPagerScreen> createState() => ProfilesPagerScreenState();
}

/// Estado de [ProfilesPagerScreen], público porque la navegación externa lo
/// alcanza a través de `GlobalKey` dentro de `FriendsPagerController`
/// (`goHome` / `jumpToProfile`).
class ProfilesPagerScreenState extends State<ProfilesPagerScreen> {
  /// Índice del perfil visible dentro de la secuencia [Home(0), amigo1, ...].
  /// Las páginas del pager son [current - 1], [current] y [current + 1] en
  /// torno a la página central.
  late int _currentIndex;
  late final PageController _controller;

  /// Dirección a la que se deslizó (0, ±1), pendiente de aplicar recién
  /// cuando el scroll se asiente.
  int _pendingDirection = 0;

  int get _total => 1 + context.read<FriendsProvider>().friends.length;

  int get _clampedIndex => _currentIndex.clamp(0, _total - 1);

  bool get _atLeftEdge => _clampedIndex == 0;

  bool get _atRightEdge => _clampedIndex == _total - 1;

  /// Página que muestra al perfil actual dentro de la ventana. En el borde
  /// izquierdo (el Home, sin nadie antes) el centro es la página 0; en el
  /// resto, la página 1 (mismo criterio que el detalle de días).
  int get _centerPage => _atLeftEdge ? 0 : 1;

  /// Cuando ya estamos en un borde no existe página "siguiente" o
  /// "anterior": con itemCount 2 el swipe rebota en el borde (sin una página
  /// que renderizar) y [onPageChanged] nunca cruza el límite.
  int get _pageCount {
    if (_total <= 1) return 1;
    if (_atLeftEdge || _atRightEdge) return 2;
    return 3;
  }

  /// Mapea el índice de página de la ventana al índice de la secuencia
  /// [Home(0), amigo1, ...]. Con la fórmula centrada cubre los tres casos:
  /// centro en 0 (borde izquierdo) o en 1 (borde derecho / medio).
  int _indexForPage(int page) {
    final raw = _clampedIndex + (page - _centerPage);
    return raw.clamp(0, _total - 1);
  }

  /// Perfil dueño de una página de la ventana: null = el Home real.
  Profile? _ownerForPage(int page) {
    final listIndex = _indexForPage(page);
    if (listIndex == 0) return null;
    final friends = context.read<FriendsProvider>().friends;
    final friendIndex = listIndex - 1;
    if (friendIndex >= 0 && friendIndex < friends.length) {
      return friends[friendIndex];
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Siempre arrancamos en la página central del Home (0). Nunca hay rebase
    // inicial: el offset queda en una sola página y la selección de la
    // píldora remarca mi avatar.
    _currentIndex = 0;
    _controller = PageController(initialPage: _centerPage);
    // El pager DEBE enterarse cuando carga/cambia la lista de amigos: el
    // itemCount (ventana de páginas) depende de ella. Sin esta suscripción la
    // ventana se queda en 1 página al arrancar (amigos aún cargando) y ni el
    // swipe ni los saltos desde la píldora encuentran la página del amigo.
    context.read<FriendsProvider>().addListener(_onFriendsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelection());
  }

  @override
  void dispose() {
    context.read<FriendsProvider>().removeListener(_onFriendsChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Los amigos cambiaron (llegaron, se agregaron o se quitaron): se fuerza el
  /// rebuild para que la ventana de páginas recalcule y el swipe/saltos
  /// sigan funcionando.
  void _onFriendsChanged() {
    if (mounted) setState(() {});
  }

  /// Solo registra la dirección del swipe; el cambio de perfil NO se hace acá
  /// porque este evento dispara al cruzar la mitad de la pantalla, con el
  /// dedo todavía abajo: rebasear ahí hace que la página salte brusca por
  /// delante de la mitad del gesto.
  void _onPageChanged(int page) {
    if (page == _centerPage) {
      _pendingDirection = 0;
      return;
    }
    _pendingDirection = page < _centerPage ? -1 : 1;
  }

  /// Aplica el perfil nuevo y rebasa al centro cuando el scroll ya se asentó:
  /// el gesto terminó, así que el salto a la página central no se ve y la
  /// página central pasa a mostrar (con el mismo contenido que venía de la
  /// página lateral) el perfil recién elegido.
  void _applyPendingRebase() {
    if (_pendingDirection == 0) return;
    final direction = _pendingDirection;
    _pendingDirection = 0;
    final next = _currentIndex + direction;
    // Defensa extra por si el itemCount llegara a cruzar un borde (no
    // debería): en los bordes simplemente se vuelve al centro sin moverse.
    if (next < 0 || next >= _total) {
      _controller.jumpToPage(_centerPage);
      return;
    }
    setState(() {
      _currentIndex = next;
    });
    _syncSelection();
    // Sin animación: al estar idle no interfiere con ningún gesto.
    _controller.jumpToPage(_centerPage);
  }

  /// La píldora del hub remarca el perfil visible: mi avatar en el Home
  /// (null) y el amigo correspondiente en cada página de amigo.
  void _syncSelection() {
    final owner = _ownerForPage(_centerPage);
    context.read<FriendsProvider>().selectProfile(owner?.id);
  }

  /// Índice (dentro de la secuencia) del perfil al que quiere saltar la
  /// navegación externa: null/Home → 0, id de un amigo → su posición; si el
  /// amigo no existe devuelve -1.
  int _targetIndexFor(String? friendId) {
    if (friendId == null) return 0;
    final friends = context.read<FriendsProvider>().friends;
    final index = friends.indexWhere((f) => f.id == friendId);
    return index < 0 ? -1 : index + 1;
  }

  /// Vuelve a la página 0 (el Home real) deslizando programáticamente por la
  /// ventana. Si ya estamos en el Home no hace nada.
  void goHome() {
    if (!mounted || _clampedIndex == 0) return;
    _navigateToIndex(0);
  }

  /// Salta al perfil de un amigo (o al Home si [friendId] es null) dentro del
  /// pager. Sin efecto si no existe o si ya está a la vista.
  void jumpToProfile(String? friendId) {
    if (!mounted) return;
    final target = _targetIndexFor(friendId);
    if (target < 0 || target == _clampedIndex) return;
    _navigateToIndex(target);
  }

  /// Retorna al Home de inmediato (para el back del sistema): sin animación,
  /// la pantalla cambia en el mismo frame y la píldora vuelve a remarcar mi
  /// avatar.
  void _goHomeInstant() {
    _pendingDirection = 0;
    setState(() {
      _currentIndex = 0;
    });
    _syncSelection();
    _controller.jumpToPage(_centerPage);
  }

  /// Salto programático a un índice cualquiera avanzando de a una página por
  /// la ventana: cada `animateToPage` cruza una página, el asentamiento la
  /// rebasa al centro (idéntico rebase del gesto) y así sucesivamente hasta
  /// llegar al destino. Viajar varios perfiles se siente como deslizarse.
  Future<void> _navigateToIndex(int target) async {
    while (mounted && _clampedIndex != target) {
      final before = _clampedIndex;
      final direction = target > _clampedIndex ? 1 : -1;
      final nextPage = _centerPage + direction;
      if (nextPage >= _pageCount) return;
      await _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      // El asentamiento del scroll normalmente ya aplicó el rebase (vía la
      // notificación); si el futuro ganó la carrera, se fuerza acá. El rebase
      // es idempotente (frena con _pendingDirection == 0).
      _applyPendingRebase();
      // Sin avance (p.ej. pager oculto bajo rutas con viewport en 0): se corta
      // el salto para no quedarse girando en el loop.
      if (_clampedIndex == before) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si la lista de amigos cambió afuera y el índice quedó fuera de rango,
    // se recoloca en el último amigo disponible sin romper la secuencia.
    final clamped = _clampedIndex;
    if (clamped != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = clamped;
        });
        _syncSelection();
        _controller.jumpToPage(_centerPage);
      });
    }

    return PopScope(
      // El back del sistema solo puede cerrar la app desde el Home; sobre el
      // perfil de un amigo vuelve al Home.
      canPop: clamped == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHomeInstant();
      },
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _applyPendingRebase();
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          itemCount: _pageCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, page) {
            final owner = _ownerForPage(page);
            if (owner == null) {
              return const HomeScreen(key: ValueKey('home'));
            }
            return FriendProfilePage(
              key: ValueKey('f:${owner.id}'),
              friend: owner,
            );
          },
        ),
      ),
    );
  }
}