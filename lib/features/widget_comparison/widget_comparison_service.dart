import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_type.dart';
import '../../data/mood_view_data.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
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
/// primer plano el widget se re-fresca solo cada minuto (las DOS burbujas:
/// la mía y la de mi amigo).
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
  Timer? _friendDebounce;
  Timer? _minuteTimer;
  bool _refreshRunning = false;
  bool _disposed = false;
  RealtimeChannel? _friendChannel;

  String? get friendId => _friendId;
  String? get friendName => _friendName;
  FriendMoodViewData? get friendView => _friendView;
  bool get rendering => _rendering;
  String? get lastError => _lastError;
  DateTime? get lastRenderedAt => _lastRenderedAt;

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
    // Re-fresca el snapshot del amigo y publica la escena completa (igual
    // que al volver a la app): así la burbuja del amigo también se
    // mantiene al día, no solo la mía.
    unawaited(refresh());
    // Además, mientras la app está en primer plano el widget se re-fresca
    // solo cada minuto.
    _startPeriodicRefresh();
    // Y se mantiene atento a los cambios del amigo en la nube (Realtime):
    // cuando él registre su ánimo, la burbuja se actualiza al instante.
    _subscribeToFriendChanges();
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
    // El amigo cambió: re-suscribo el canal Realtime al nuevo id.
    _subscribeToFriendChanges();
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
  /// re-fresca el snapshot remoto del amigo: así SU burbuja también se
  /// mantiene al día, no solo la mía. Si la red falla, se conserva el
  /// último snapshot guardado. Si ya hay una ejecución en curso, la nueva
  /// llamada se descarta (evita solapamientos al soltar varias fuentes).
  Future<void> refresh() async {
    if (_refreshRunning) return;
    _refreshRunning = true;
    try {
      _debounce?.cancel();
      _debounce = null;
      await _refreshFriendSnapshot();
      await _publish();
    } finally {
      _refreshRunning = false;
    }
  }

  /// Actualiza las dos burbujas del widget automáticamente cada minuto
  /// mientras la app está en primer plano (además de los disparadores
  /// manuales: cada toque mío, re-selección de amigo, resume y el botón
  /// "Actualizar burbujas").
  static const Duration _periodicRefreshPeriod = Duration(minutes: 1);

  void _startPeriodicRefresh() {
    _minuteTimer?.cancel();
    _minuteTimer = Timer.periodic(_periodicRefreshPeriod, (_) {
      if (_disposed) return;
      unawaited(refresh());
    });
  }

  /// Mantiene el widget atento a los cambios del amigo en la nube
  /// (Supabase Realtime). Al insertar/actualizar/borrar un registro de
  /// ánimo o un color del catálogo del amigo, el widget re-fresca la
  /// burbuja de inmediato sin tocar nada. La RLS de "amigos" ya da acceso
  /// de SELECT a esas tablas, así que Realtime entrega solo las filas de
  /// ese usuario. Mientras la app vive (incluso en segundo plano) los
  /// cambios llegan en vivo; con la app cerrada no hay procesamiento.
  void _subscribeToFriendChanges() {
    _unsubscribeFromFriendChanges();
    final id = _friendId;
    if (id == null || id.isEmpty) return;
    try {
      _friendChannel = Supabase.instance.client
          .channel('widget-friend-$id')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'mood_entries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: id,
            ),
            callback: (_) => _onFriendChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'mood_catalog',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: id,
            ),
            callback: (_) => _onFriendChanged(),
          );
      _friendChannel = _friendChannel?.subscribe();
    } catch (_) {
      // Sin Realtime no pasa nada: el widget igual se refresca por el
      // timer, resume y el botón.
    }
  }

  void _unsubscribeFromFriendChanges() {
    _friendDebounce?.cancel();
    _friendDebounce = null;
    final channel = _friendChannel;
    _friendChannel = null;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {
        // El canal ya estaba cerrado.
      }
    }
  }

  void _onFriendChanged() {
    if (_disposed) return;
    // Agrupa ráfagas de cambios (p. ej. el amigo registra varios ánimos de
    // una vez) en una sola re-publicación.
    _friendDebounce?.cancel();
    _friendDebounce = Timer(const Duration(milliseconds: 600), () {
      _friendDebounce = null;
      unawaited(refresh());
    });
  }

  /// Trae de nuevo el snapshot remoto del amigo elegido (registros +
  /// catálogo) y lo persiste. No se lanza en cada toque mío (sería una
  /// consulta por mutación): se corre al arrancar la app, al volver a ella
  /// y en el botón "Actualizar burbujas". Si la red falla se conserva el
  /// snapshot previo para que el widget siga mostrando el último dato
  /// conocido en vez de quedarse en blanco.
  Future<void> _refreshFriendSnapshot() async {
    final id = _friendId;
    if (id == null || id.isEmpty) return;
    try {
      final fresh = await fetchFriendMoodViewData(id);
      _friendView = fresh;
      _lastFetchedFriendId = id;
      _lastError = null;
      await _persistSnapshot();
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
  /// dibuja desde el cache con Kotlin.
  Future<void> _publish() async {
    if (_rendering) return;
    _rendering = true;
    _lastError = null;
    notifyListeners();
    try {
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
      await refreshWidgetPreview();
      _lastRenderedAt = DateTime.now();
    } catch (_) {
      _lastError = 'No se pudo actualizar el widget.';
    } finally {
      _rendering = false;
      notifyListeners();
    }
  }

  String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _minuteTimer?.cancel();
    _unsubscribeFromFriendChanges();
    moodProvider.removeListener(_onDataChanged);
    catalogProvider.removeListener(_onDataChanged);
    super.dispose();
  }
}