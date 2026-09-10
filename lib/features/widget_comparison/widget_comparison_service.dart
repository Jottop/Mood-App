import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_type.dart';
import '../../data/mood_view_data.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import 'mood_comparison_scene.dart';

/// Orquesta el widget de comparación del escritorio:
///
///  * guarda el amigo elegido y un SNAPSHOT local de sus datos (para que el
///    widget ande sin conexión y para no volver a consultar Supabase en cada
///    actualización de la burbuja),
///  * recalcula la escena "mía vs. amigo" y la rasteriza a un PNG que vive
///    en el storage del widget (`HomeWidget.saveFile`),
///  * le avisa al sistema que actualice el AppWidget.
///
/// Cada cambio en mis registros/catálogo re-renderiza con un pequeño
/// debounce; al volver a la app (resume) y al seleccionar amigo o tocar
/// "Actualizar burbujas" se fuerza de inmediato.
class WidgetComparisonService extends ChangeNotifier {
  WidgetComparisonService({
    required this.moodProvider,
    required this.catalogProvider,
  }) {
    _scheduleOnChange();
  }

  static const _prefFriendId = 'widget_comparison_friend_id';
  static const _prefFriendName = 'widget_comparison_friend_name';
  static const _prefFriendEntries = 'widget_comparison_friend_entries';
  static const _prefFriendCatalog = 'widget_comparison_friend_catalog';

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
  bool _disposed = false;

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
    _friendId = _nonEmpty(prefs.getString(_prefFriendId));
    _friendName = _nonEmpty(prefs.getString(_prefFriendName));
    final entriesJson = prefs.getString(_prefFriendEntries);
    final catalogJson = prefs.getString(_prefFriendCatalog);
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
    unawaited(_publish());
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
  }

  Future<void> _persistSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFriendId, _friendId ?? '');
    await prefs.setString(_prefFriendName, _friendName ?? '');
  }

  Future<void> _persistSnapshot() async {
    final view = _friendView;
    final prefs = await SharedPreferences.getInstance();
    if (view == null) {
      await prefs.remove(_prefFriendEntries);
      await prefs.remove(_prefFriendCatalog);
      return;
    }
    final entries = jsonEncode([for (final e in view.allEntries) e.toJson()]);
    final catalog = jsonEncode([for (final m in view.catalogMoods) m.toJson()]);
    await prefs.setString(_prefFriendEntries, entries);
    await prefs.setString(_prefFriendCatalog, catalog);
  }

  /// Fuerza una re-publicación inmediata (botón "Actualizar burbujas",
  /// resume de la app).
  Future<void> refresh() async {
    _debounce?.cancel();
    _debounce = null;
    await _publish();
  }

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
      final bytes = await renderComparisonScenePng(
        mine,
        friend,
        friendLabel: _friendName ?? '—',
      );
      await HomeWidget.saveFile('comparison_image', bytes, extension: 'png');
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.mood_app.MoodComparisonProvider',
      );
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
    moodProvider.removeListener(_onDataChanged);
    catalogProvider.removeListener(_onDataChanged);
    super.dispose();
  }
}