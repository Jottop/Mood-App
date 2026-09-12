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
///
/// El flush es SERIALIZADO y autocompactante: si una escritura está en curso
/// y llega otra mutación, no se lanza una segunda en paralelo (la anterior
/// podría borrar filas que la nueva acaba de escribir); se espera a que
/// termine y se corre el set completo de nuevo. [flushNow] espera a que toda
/// la cadena termine, así al pausar la app nunca se mata un guardado a
/// medias.
class DebouncedPersistence {
  DebouncedPersistence(
    this._flush, {
    this.delay = const Duration(milliseconds: 400),
  });

  final Future<void> Function() _flush;
  final Duration delay;

  Timer? _timer;
  Future<void>? _loop;
  bool _pending = false;

  /// Marca el estado como pendiente de guardar y agenda la escritura dentro
  /// de [delay]. Si ya había una agendada, la reemplaza (no acumula).
  void schedule() {
    _pending = true;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      _flushLoop();
    });
  }

  /// Guarda ahora mismo si hay un guardado pendiente y espera a que termine
  /// toda la cadena (incluido un flush que ya estuviera corriendo y los que
  /// este haya re-agendado).
  Future<void> flushNow() async {
    _timer?.cancel();
    _timer = null;
    if (_pending) {
      _pending = true;
      await _flushLoop();
    }
  }

  /// Corre el bucle de escritura una vez; si ya está corriendo, devuelve el
  /// futuro en curso (no lanza un flush en paralelo).
  Future<void> _flushLoop() {
    final running = _loop;
    if (running != null) return running;
    final future = _runLoop();
    _loop = future;
    return future;
  }

  Future<void> _runLoop() async {
    try {
      // Repite mientras lleguen mutaciones: las que ocurran DURANTE un flush
      // (no solo las que lo agendaron) quedan cubiertas por la siguiente
      // vuelta sin riesgo de pisar una escritura a medias.
      while (_pending) {
        _pending = false;
        await _flush();
      }
    } finally {
      _loop = null;
    }
  }
}