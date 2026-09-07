import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/mood_entry.dart';
import '../data/repositories/mood_repository.dart';
import '../services/date_service.dart';
import 'debounced_persistence.dart';

/// Única fuente de verdad del estado de la app: mantiene los registros en
/// memoria, delega la persistencia al [MoodRepository] inyectado, y expone
/// vistas derivadas (registros de hoy, historial agrupado por día) que las
/// pantallas solo necesitan leer.
///
/// Las vistas derivadas se mantienen en un índice por día ([_byDay]) que
/// se reconstruye únicamente al mutar [_entries], así ningún build vuelve
/// a recorrer ni a ordenar todos los registros (ni asigna strings por día).
/// La escritura a disco se difiere ([_persistence]) para agrupar toques
/// rápidos en un solo guardado; [flushNow] fuerza el guardado pendiente
/// (lo usa el ciclo de vida de la app al pausarla).
class MoodProvider extends ChangeNotifier {
  MoodProvider({required MoodRepository repository}) : _repository = repository;

  final MoodRepository _repository;
  final _uuid = const Uuid();

  List<MoodEntry> _entries = [];
  bool _loading = true;

  // Índice derivado: clave de día entera -> registros de ese día, en
  // orden cronológico. Se reconstruye al mutar _entries.
  Map<int, List<MoodEntry>> _byDay = {};

  // El historial agrupado (excluyendo hoy) se calcula una vez por cambio.
  Map<String, List<MoodEntry>>? _historyCache;

  late final DebouncedPersistence _persistence = DebouncedPersistence(
    () => _repository.saveAll(_entries),
  );

  bool get loading => _loading;

  List<MoodEntry> get allEntries => List.unmodifiable(_entries);

  /// Registros de hoy, de más antiguo a más reciente (útil para el
  /// cálculo de color de la burbuja). Lista de solo lectura: no se debe
  /// modificar.
  List<MoodEntry> get todaysEntriesAsc {
    final today = DateService.localDayKey(DateTime.now());
    return _byDay[today] ?? const <MoodEntry>[];
  }

  /// Registros de hoy, de más reciente a más antiguo (para el listado
  /// visible en pantalla, spec §2).
  List<MoodEntry> get todaysEntriesDesc => todaysEntriesAsc.reversed.toList();

  /// Registros de un día cualquiera (pasado, hoy o futuro), de más
  /// antiguo a más reciente (busca en el índice, O(1), y devuelve la
  /// lista cacheada de solo lectura). Útil para el calendario del
  /// historial, que consulta todos los días del mes.
  List<MoodEntry> entriesForDateAsc(DateTime date) =>
      _byDay[DateService.localDayKey(date)] ?? const <MoodEntry>[];

  List<MoodEntry> entriesForDateDesc(DateTime date) =>
      entriesForDateAsc(date).reversed.toList();

  /// Historial agrupado por día (clave "YYYY-MM-DD"), excluyendo hoy.
  /// Cada lista interna viene ordenada de más reciente a más antiguo.
  Map<String, List<MoodEntry>> get historyByDay {
    final cached = _historyCache;
    if (cached != null) return cached;

    final todayKey = DateService.localDayKey(DateTime.now());
    final days = _byDay.keys.where((k) => k != todayKey).toList()
      ..sort((a, b) => b.compareTo(a));
    final Map<String, List<MoodEntry>> groups = {};
    for (final day in days) {
      final asc = _byDay[day]!;
      groups[DateService.dateKey(asc.first.timestamp)] = asc.reversed.toList();
    }
    _historyCache = groups;
    return groups;
  }

  void _setEntries(List<MoodEntry> entries) {
    _entries = entries;
    _historyCache = null;

    // Reconstruye el índice por día y lo deja ordenado por timestamp.
    // Costo O(N log N) solo al mutar, nunca en los builds.
    final byDay = <int, List<MoodEntry>>{};
    for (final e in entries) {
      final day = DateService.localDayKey(e.timestamp);
      byDay.putIfAbsent(day, () => []).add(e);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    _byDay = byDay;
  }

  Future<void> load() async {
    final loaded = await _repository.loadAll();
    _setEntries(loaded);
    _loading = false;
    notifyListeners();
  }

  /// Fuerza la escritura pendiente (si la hay). Lo invoca el ciclo de
  /// vida de la app al pausarla/destruirla, para no perder el último toque.
  Future<void> flushNow() => _persistence.flushNow();

  /// Registra un nuevo estado de ánimo con fecha/hora automática
  /// (spec §5). No reemplaza registros anteriores.
  Future<void> addEntry(String moodId) async {
    final now = DateTime.now();
    final entry = MoodEntry(
      id: _uuid.v4(),
      moodId: moodId,
      timestamp: now,
      loggedAt: now,
    );
    _setEntries([..._entries, entry]);
    notifyListeners();
    _persistence.schedule();
  }

  /// Registra un estado de ánimo para un día distinto a hoy (por ejemplo,
  /// desde el calendario del historial). Queda marcado como "anotado
  /// después" porque loggedAt (ahora) no coincide con el día de [forDate].
  Future<void> addEntryForDate(String moodId, DateTime forDate) async {
    final now = DateTime.now();
    // Usamos la fecha elegida, con la hora actual (no tenemos un selector
    // de hora específico), para mantener el orden cronológico razonable.
    final timestamp = DateTime(forDate.year, forDate.month, forDate.day, now.hour, now.minute, now.second);
    final entry = MoodEntry(
      id: _uuid.v4(),
      moodId: moodId,
      timestamp: timestamp,
      loggedAt: now,
    );
    _setEntries([..._entries, entry]);
    notifyListeners();
    _persistence.schedule();
  }

  /// Elimina un registro puntual del listado (spec: opción de eliminar
  /// un estado del listado).
  Future<void> deleteEntry(String id) async {
    _setEntries(_entries.where((e) => e.id != id).toList());
    notifyListeners();
    _persistence.schedule();
  }

  /// Borra todos los registros del día actual (no toca días anteriores).
  Future<void> resetToday() async {
    final now = DateTime.now();
    final todayKey = DateService.localDayKey(now);
    _setEntries(_entries.where((e) => DateService.localDayKey(e.timestamp) != todayKey).toList());
    notifyListeners();
    _persistence.schedule();
  }
}