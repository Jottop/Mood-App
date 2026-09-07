import 'dart:async';

/// Agrupa llamadas de persistencia espaciadas en el tiempo.
///
/// Cada mutación del provider llama [schedule] en vez de escribir a disco
/// de inmediato: si vienen varias seguidas (p. ej. varios toques sobre los
/// estados de ánimo), todas se resuelven en una sola escritura. La UI se
/// notifica igual en cada mutación; solo se difiere el guardado.
///
/// [flushNow] fuerza el guardado de inmediato (si hay algo pendiente) y lo
/// usan los providers al pausar/detener la app, para no perder el último
/// cambio si la matan de repente justo después de un toque.
class DebouncedPersistence {
  DebouncedPersistence(
    this._flush, {
    this.delay = const Duration(milliseconds: 400),
  });

  final Future<void> Function() _flush;
  final Duration delay;

  Timer? _timer;

  /// Marca el estado como pendiente de guardar y agenda la escritura dentro
  /// de [delay]. Si ya había una agendada, la reemplaza (no acumula).
  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      _flush();
    });
  }

  /// Guarda ahora mismo si hay un guardado pendiente.
  Future<void> flushNow() async {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    await _flush();
  }
}