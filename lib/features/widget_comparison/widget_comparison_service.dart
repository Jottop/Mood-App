import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_type.dart';
import '../../data/mood_view_data.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import 'widget_background_sync.dart';
import 'widget_bg_prefs.dart';
import 'widget_cache_store.dart';

/// Orquesta el widget de comparación del escritorio:
///
///  * guarda el amigo elegido y un SNAPSHOT local de sus datos (para que el
///    widget ande sin conexión y para no volver a consultar Supabase en cada
///    actualización de la burbuja),
///  * recalcula la escena "mía vs. amigo" y la guarda como cache (colores y
///    etiquetas) en el storage del widget (`HomeWidget.saveWidgetData`); el
///    AppWidget la DIBUJA en nativo (Kotlin), sin depender del motor Flutter,
///  * le avisa al sistema que actualice el AppWidget.
///
/// Cada cambio en mis registros/catálogo re-renderiza con un pequeño
/// debounce; al volver a la app (resume), al seleccionar amigo o tocar
/// "Actualizar burbujas" se fuerza de inmediato, y mientras la app está en
/// primer plano y HAY amigo elegido el widget se re-fresca solo cada minuto.
/// Ese refresco periódico usa un "fingerprint" remoto barato (~2 consultas
/// ligeras) y solo re-descarga el historial completo del amigo cuando algo
/// cambió de verdad. Sin Realtime: la publicación `supabase_realtime` ya no
/// incluye las tablas del amigo (era la mayor carga de la BD) y el minuto de
/// latencia no se nota en la burbuja.
class WidgetComparisonService extends ChangeNotifier {
  WidgetComparisonService({
    required this.moodProvider,
    required this.catalogProvider,
  }) {
    _scheduleOnChange();
  }

  final MoodProvider moodProvider;
  final MoodCatalogProvider catalogProvider;

  String? _friendId;
  String? _friendName;
  String? _lastFetchedFriendId;
  FriendMoodViewData? _friendView;
  bool _rendering = false;
  String? _lastError;
  DateTime? _lastRenderedAt;

  Timer? _debounce;
  Timer? _minuteTimer;
  bool _refreshRunning = false;
  bool _disposed = false;

  String? get friendId => _friendId;
  String? get friendName => _friendName;
  FriendMoodViewData? get friendView => _friendView;
  bool get rendering => _rendering;
  String? get lastError => _lastError;
  DateTime? get lastRenderedAt => _lastRenderedAt;

  /// Color de fondo personalizado del widget (`null` = degradado clásico).
  /// Lo publica [widgetBgColor]; la pantalla de configuración lo escucha.
  Color? get widgetBackgroundColor => widgetBgColor.value;

  bool get hasFriend => _friendId != null && _friendId!.isNotEmpty;

  void _scheduleOnChange() {
    moodProvider.addListener(_onDataChanged);
    catalogProvider.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _debounce = null;
      unawaited(_publish());
    });
  }

  /// Carga la configuración guardada (amigo elegido + snapshot) y publica la
  /// escena actual. Se invoca al crear el servicio.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _friendId = _nonEmpty(prefs.getString(kWidgetPrefFriendId));
    _friendName = _nonEmpty(prefs.getString(kWidgetPrefFriendName));
    final entriesJson = prefs.getString(kWidgetPrefFriendEntries);
    final catalogJson = prefs.getString(kWidgetPrefFriendCatalog);
    if (entriesJson != null && catalogJson != null) {
      try {
        final entries = (jsonDecode(entriesJson) as List)
            .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        final catalog = (jsonDecode(catalogJson) as List)
            .map((e) => MoodType.fromJson(e as Map<String, dynamic>))
            .toList();
        _friendView = FriendMoodViewData(entries: entries, catalog: catalog);
        _lastFetchedFriendId = _friendId;
      } catch (_) {
        _friendView = null;
      }
    }
    notifyListeners();
    // Fondo personalizado del widget (prefs locales) para las publicaciones.
    await loadWidgetBgColor();
    // Re-fresca el snapshot del amigo (con dirty-check) y publica la escena
    // completa (igual que al volver a la app): la burbuja del amigo también
    // se mantiene al día, no solo la mía.
    unawaited(refresh());
    // Con amigo elegido el fondo necesita el token de solo lectura para
    // refrescar el widget con la app cerrada (sin rotar la sesión).
    if (hasFriend) unawaited(ensureWidgetComparisonToken());
    // Con amigo elegido, el widget se re-fresca solo cada minuto.
    _ensurePeriodicRefresh();
  }

  /// Elige el amigo cuya burbuja se compara. Carga su snapshot (del último
  /// amigo elegido si coincide, o remoto en cualquier otro caso) y
  /// re-publica la escena.
  Future<void> selectFriend(String? friendId, {String? displayName}) async {
    if (friendId == _friendId && displayName == _friendName) return;
    _friendId = friendId;
    _friendName = displayName;
    _lastError = null;
    notifyListeners();
    try {
      if (friendId == null) {
        _friendView = null;
      } else if (_lastFetchedFriendId != friendId) {
        _friendView = await fetchFriendMoodViewData(friendId);
        _lastFetchedFriendId = friendId;
        await _persistSnapshot();
      }
    } catch (_) {
      _lastError = 'No se pudo cargar la burbuja del amigo. Revisa la conexión.';
    }
    await _persistSelection();
    notifyListeners();
    unawaited(_publish());
    _ensurePeriodicRefresh();
    if (friendId != null) {
      // Elegir amigo (re)planta el primer eslabón de la cadena de fondo: si el
      // one-off inicial de la sesión ya se consumió sin amigo, esta reanuda
      // el refresco del widget con la app cerrada.
      unawaited(scheduleNextWidgetSync());
      // El fondo consume el token de solo lectura (nunca la sesión): se
      // asegura de que exista antes de replantar la cadena.
      unawaited(ensureWidgetComparisonToken());
    }
  }

  Future<void> _persistSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWidgetPrefFriendId, _friendId ?? '');
    await prefs.setString(kWidgetPrefFriendName, _friendName ?? '');
  }

  Future<void> _persistSnapshot() async {
    final view = _friendView;
    final prefs = await SharedPreferences.getInstance();
    if (view == null) {
      await prefs.remove(kWidgetPrefFriendEntries);
      await prefs.remove(kWidgetPrefFriendCatalog);
      return;
    }
    final entries = jsonEncode([for (final e in view.allEntries) e.toJson()]);
    final catalog = jsonEncode([for (final m in view.catalogMoods) m.toJson()]);
    await prefs.setString(kWidgetPrefFriendEntries, entries);
    await prefs.setString(kWidgetPrefFriendCatalog, catalog);
  }

  /// Fuerza una re-publicación inmediata (botón "Actualizar burbujas",
  /// resume de la app, temporizador de cada minuto). Antes de renderizar
  /// re-fresca el snapshot remoto del amigo (solo si su fingerprint cambió):
  /// así SU burbuja también se mantiene al día, no solo la mía. Si la red
  /// falla, se conserva el último snapshot guardado. Si ya hay una ejecución
  /// en curso, la nueva llamada se descarta (evita solapamientos al soltar
  /// varias fuentes).
  Future<void> refresh() async {
    if (_refreshRunning) return;
    _refreshRunning = true;
    try {
      _debounce?.cancel();
      _debounce = null;
      await _maybeRefreshFriendSnapshot();
      await _publish();
    } finally {
      _refreshRunning = false;
    }
  }

  /// Actualiza las dos burbujas del widget automáticamente cada minuto
  /// mientras la app está en primer plano Y hay amigo elegido (sin amigo el
  /// widget solo muestra "mía", que ya se publica en cada cambio/resume).
  static const Duration _periodicRefreshPeriod = Duration(minutes: 1);

  void _ensurePeriodicRefresh() {
    if (!hasFriend) {
      _minuteTimer?.cancel();
      _minuteTimer = null;
      return;
    }
    if (_minuteTimer != null) return;
    _minuteTimer = Timer.periodic(_periodicRefreshPeriod, (_) {
      if (_disposed) return;
      unawaited(refresh());
    });
  }

  /// Trae de nuevo el snapshot remoto del amigo elegido (registros +
  /// catálogo) y lo persiste SOLO si su fingerprint remoto difiere del local:
  /// registra ~1 consulta ligera + el catálogo diminuto por minuto en vez del
  /// historial completo. No se lanza en cada toque mío (sería una consulta
  /// por mutación): corre al arrancar la app, al volver a ella y en el botón
  /// "Actualizar burbujas". Si la red falla se conserva el snapshot previo
  /// para que el widget siga mostrando el último dato conocido en vez de
  /// quedarse en blanco.
  Future<void> _maybeRefreshFriendSnapshot() async {
    final id = _friendId;
    _lastError = null;
    if (id == null || id.isEmpty) {
      _friendView = null;
      notifyListeners();
      return;
    }
    try {
      final freshFingerprint = await friendDataFingerprint(id);
      final current = _friendView;
      final stale = current == null ||
          friendViewFingerprint(current) != freshFingerprint;
      if (stale) {
        final fresh = await fetchFriendMoodViewData(id);
        _friendView = fresh;
        _lastFetchedFriendId = id;
        await _persistSnapshot();
      }
    } catch (_) {
      // Red caída: el widget sigue con el snapshot guardado.
      if (_friendView == null) {
        _lastError = 'No se pudo conectar para cargar la burbuja del amigo.';
      }
    }
    notifyListeners();
  }

  /// Escribe el cache de la escena (colores de hoy + etiquetas) y le pide al
  /// widget que se repinte en nativo. No se rasteriza ningún PNG: el AppWidget
  /// dibuja desde el cache con Kotlin. De paso renueva el heartbeat de la app
  /// en primer plano (la tarea de fondo WorkManager lo consulta para no
  /// consumir el token compartido mientras esta app está activa).
  Future<void> _publish() async {
    if (_rendering) return;
    _rendering = true;
    _lastError = null;
    notifyListeners();
    try {
      await _touchHeartbeat();
      final today = DateTime.now();
      final local = LocalMoodViewData(provider: moodProvider, catalog: catalogProvider);
      final mine = dayBubbleData(local, today);
      final friendView = _friendView;
      final friend = friendView == null
          ? const DayBubbleData(colorsTopToBottom: [])
          : dayBubbleData(friendView, today);
      await saveWidgetDateKey(widgetDateKey(today));
      await saveWidgetMine(mine: mine);
      await saveWidgetFriend(
        friend: friend,
        label: _friendName ?? '—',
      );
      // El fondo personalizado también viaja en cada publicación: si el
      // storage se limpiara, el widget recupera el color la próxima vez.
      final bg = widgetBgColor.value;
      if (bg != null) {
        await saveWidgetBackground(bg.toARGB32());
      }
      await refreshWidgetPreview();
      _lastRenderedAt = DateTime.now();
    } catch (_) {
      _lastError = 'No se pudo actualizar el widget.';
    } finally {
      _rendering = false;
      notifyListeners();
    }
  }

  Future<void> _touchHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      kWidgetPrefAppActiveAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _minuteTimer?.cancel();
    moodProvider.removeListener(_onDataChanged);
    catalogProvider.removeListener(_onDataChanged);
    super.dispose();
  }
}