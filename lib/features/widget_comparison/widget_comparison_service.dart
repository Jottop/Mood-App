import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_type.dart';
import '../../data/mood_view_data.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import 'widget_background_sync.dart';
import 'widget_cache_store.dart';

/// Orquesta el widget de comparación del escritorio:
///
///  * guarda hasta 2 amigos elegidos (con "Yo" siempre como 1.ª burbuja), la
///    disposición (horizontal/vertical) y un SNAPSHOT local de los datos de
///    cada amigo (para que el widget ande sin conexión y para no volver a
///    consultar Supabase en cada actualización de la burbuja),
///  * recalcula la escena (1 a 3 burbujas) y la guarda como cache (colores y
///    etiquetas) en el storage del widget (`HomeWidget.saveWidgetData`); el
///    AppWidget la DIBUJA en nativo (Kotlin), sin depender del motor Flutter,
///  * le avisa al sistema que actualice el AppWidget.
///
/// Cada cambio en mis registros/catálogo re-renderiza con un pequeño
/// debounce; al volver a la app (resume), al elegir amigos o tocar "Actualizar
/// burbujas" se fuerza de inmediato, y mientras la app está en primer plano y
/// HAY amigo elegido el widget se re-fresca solo cada minuto. Ese refresco
/// periódico usa un "fingerprint" remoto barato (~2 consultas ligeras por
/// amigo) y solo re-descarga el historial completo del amigo cuando algo
/// cambió de verdad.
class WidgetComparisonService extends ChangeNotifier {
  WidgetComparisonService({
    required this.moodProvider,
    required this.catalogProvider,
  }) {
    _scheduleOnChange();
  }

  final MoodProvider moodProvider;
  final MoodCatalogProvider catalogProvider;

  List<String> _friendIds = const [];
  List<String> _friendNames = const [];
  final Map<String, FriendMoodViewData> _friendViews = {};
  WidgetLayout _layout = WidgetLayout.horizontal;
  bool _rendering = false;
  String? _lastError;
  DateTime? _lastRenderedAt;

  Timer? _debounce;
  Timer? _minuteTimer;
  bool _refreshRunning = false;
  bool _disposed = false;

  /// Ids de los amigos elegidos, en orden de aparición en el widget.
  List<String> get friendIds => _friendIds;

  /// Nombres de los amigos elegidos, alineados con [friendIds].
  List<String> get friendNames => _friendNames;

  /// Snapshot del amigo indicado (o null si aún no se cargó).
  FriendMoodViewData? friendView(String id) => _friendViews[id];

  /// Disposición elegida para el widget.
  WidgetLayout get layout => _layout;

  bool get rendering => _rendering;
  String? get lastError => _lastError;
  DateTime? get lastRenderedAt => _lastRenderedAt;

  bool get hasFriends => _friendIds.isNotEmpty;

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

  /// Carga la configuración guardada (amigos, disposición y snapshots) y
  /// publica la escena actual. Se invoca al crear el servicio.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _layout = widgetLayoutFromKey(prefs.getString(kWidgetPrefLayout));

    var ids = _jsonStringList(prefs.getString(kWidgetPrefFriendIds));
    var names = _jsonStringList(prefs.getString(kWidgetPrefFriendNames));

    // Migración: instalaciones viejas guardaban un solo amigo en claves
    // planas y su snapshot en otras dos.
    final legacyId = _nonEmpty(prefs.getString(kWidgetPrefFriendId));
    if (ids.isEmpty && legacyId != null) {
      ids = [legacyId];
      names = [_nonEmpty(prefs.getString(kWidgetPrefFriendName)) ?? '—'];
    }
    if (ids.length != names.length) names = List.filled(ids.length, '—');

    final snapshotsJson = prefs.getString(kWidgetPrefFriendSnapshots);
    if (snapshotsJson != null) {
      try {
        final map = jsonDecode(snapshotsJson) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final raw = entry.value as Map<String, dynamic>;
          _friendViews[entry.key] = _snapshotFromJson(raw);
        }
      } catch (_) {
        _friendViews.clear();
      }
    }
    if (_friendViews.isEmpty && legacyId != null) {
      // Snapshot legacy (entradas + catálogo del único amigo).
      final entriesJson = prefs.getString(kWidgetPrefFriendEntries);
      final catalogJson = prefs.getString(kWidgetPrefFriendCatalog);
      if (entriesJson != null && catalogJson != null) {
        try {
          _friendViews[legacyId] = FriendMoodViewData(
            entries: (jsonDecode(entriesJson) as List)
                .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
            catalog: (jsonDecode(catalogJson) as List)
                .map((e) => MoodType.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        } catch (_) {}
      }
    }

    _friendIds = ids;
    _friendNames = names;
    notifyListeners();
    // Re-fresca los snapshots de los amigos (con dirty-check) y publica la
    // escena completa: las burbujas ajenas también se mantienen al día.
    unawaited(refresh());
    // Con amigo elegido, el widget se re-fresca solo cada minuto.
    _ensurePeriodicRefresh();
  }

  /// Reemplaza la selección de amigos (hasta 2). Carga sus snapshots (del
  /// cache, o remoto en cualquier otro caso) y re-publica la escena.
  Future<void> setFriends(List<String> ids, List<String> names) async {
    if (listEquals(ids, _friendIds) && listEquals(names, _friendNames)) {
      return;
    }
    _friendIds = List.of(ids);
    _friendNames = List.of(names);
    _lastError = null;
    notifyListeners();
    await _persist();
    unawaited(refresh());
    _ensurePeriodicRefresh();
    if (ids.isNotEmpty) {
      // (Re)planta el primer eslabón de la cadena de fondo.
      unawaited(scheduleNextWidgetSync());
    }
  }

  /// Cambia la disposición (horizontal/vertical) y re-publica la escena.
  Future<void> setLayout(WidgetLayout layout) async {
    if (_layout == layout) return;
    _layout = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWidgetPrefLayout, widgetLayoutKey(layout));
    notifyListeners();
    unawaited(_publish());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWidgetPrefLayout, widgetLayoutKey(_layout));
    await prefs.setString(kWidgetPrefFriendIds, jsonEncode(_friendIds));
    await prefs.setString(kWidgetPrefFriendNames, jsonEncode(_friendNames));
    await _persistSnapshots(prefs);
  }

  Future<void> _persistSnapshots(SharedPreferences prefs) async {
    final map = <String, dynamic>{};
    for (final entry in _friendViews.entries) {
      map[entry.key] = {
        'entries': [
          for (final e in entry.value.allEntries) e.toJson(),
        ],
        'catalog': [
          for (final m in entry.value.catalogMoods) m.toJson(),
        ],
      };
    }
    await prefs.setString(kWidgetPrefFriendSnapshots, jsonEncode(map));
  }

  /// Fuerza una re-publicación inmediata (botón "Actualizar burbujas",
  /// resume de la app, temporizador de cada minuto). Antes de renderizar
  /// re-fresca los snapshots remotos de los amigos elegidos (solo si su
  /// fingerprint cambió): así SUS burbujas también se mantienen al día. Si la
  /// red falla, se conserva el último snapshot guardado. Si ya hay una
  /// ejecución en curso, la nueva llamada se descarta (evita solapamientos).
  Future<void> refresh() async {
    if (_refreshRunning) return;
    _refreshRunning = true;
    try {
      _debounce?.cancel();
      _debounce = null;
      await _maybeRefreshFriendSnapshots();
      await _publish();
    } finally {
      _refreshRunning = false;
    }
  }

  /// Actualiza las burbujas del widget automáticamente cada minuto mientras
  /// la app está en primer plano Y hay amigo elegido.
  static const Duration _periodicRefreshPeriod = Duration(minutes: 1);

  void _ensurePeriodicRefresh() {
    if (!hasFriends) {
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

  /// Trae de nuevo los snapshots remotos de los amigos elegidos y los
  /// persiste SOLO si su fingerprint difiere del local: ~1 consulta ligera +
  /// un catálogo diminuto por amigo y minuto en vez del historial completo.
  /// No se lanza en cada toque mío (sería una consulta por mutación): corre
  /// al arrancar la app, al volver a ella, en el botón "Actualizar burbujas"
  /// y al tocar un amigo. Si la red falla se conserva el snapshot previo.
  Future<void> _maybeRefreshFriendSnapshots() async {
    if (_friendIds.isEmpty) {
      _friendViews.clear();
      notifyListeners();
      return;
    }
    var anyFailed = false;
    for (final id in _friendIds) {
      try {
        final freshFingerprint = await friendDataFingerprint(id);
        final current = _friendViews[id];
        final stale = current == null ||
            friendViewFingerprint(current) != freshFingerprint;
        if (stale) {
          _friendViews[id] = await fetchFriendMoodViewData(id);
          final prefs = await SharedPreferences.getInstance();
          await _persistSnapshots(prefs);
        }
      } catch (_) {
        // Red caída: el widget sigue con el snapshot guardado.
        if (_friendViews[id] == null) {
          anyFailed = true;
        }
      }
    }
    if (anyFailed) {
      _lastError = 'No se pudo conectar para cargar la burbuja del amigo.';
    } else {
      _lastError = null;
    }
    notifyListeners();
  }

  /// Escribe el cache de la escena (burbujas de hoy + etiquetas + layout) y
  /// le pide al widget que se repinte en nativo. No se rasteriza ningún PNG:
  /// el AppWidget dibuja desde el cache con Kotlin.
  Future<void> _publish() async {
    if (_rendering) return;
    _rendering = true;
    _lastError = null;
    notifyListeners();
    try {
      await _touchHeartbeat();
      final today = DateTime.now();
      final local =
          LocalMoodViewData(provider: moodProvider, catalog: catalogProvider);
      final mine = dayBubbleData(local, today);
      final bubbles = <({String label, DayBubbleData data})>[
        (label: 'Yo', data: mine),
      ];
      for (var i = 0; i < _friendIds.length; i++) {
        final view = _friendViews[_friendIds[i]];
        bubbles.add((
          label: _friendNames[i],
          data: view == null
              ? const DayBubbleData(colorsTopToBottom: [])
              : dayBubbleData(view, today),
        ));
      }
      await saveWidgetDateKey(widgetDateKey(today));
      await saveWidgetScene(bubbles: bubbles, layout: _layout);
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

  static FriendMoodViewData _snapshotFromJson(Map<String, dynamic> raw) {
    return FriendMoodViewData(
      entries: (raw['entries'] as List)
          .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      catalog: (raw['catalog'] as List)
          .map((e) => MoodType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<String> _jsonStringList(String? raw) {
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          if (item is String && item.isNotEmpty) item,
      ];
    } catch (_) {
      return const [];
    }
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