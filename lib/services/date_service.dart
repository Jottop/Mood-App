/// Maneja el agrupamiento por día y el formato de fechas/horas, siempre
/// en base a la hora local del dispositivo (spec §3).
class DateService {
  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static const _weekdays = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  /// Clave entera del día en horario local (Y*10000 + M*100 + D). Es la
  /// versión sin asignación de strings que usan los índices del provider
  /// (más rápido en bucles / por celda del calendario).
  static int localDayKey(DateTime dt) {
    final local = dt.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }

  /// Clave estable "YYYY-MM-DD" en horario local, usada para agrupar
  /// registros por día.
  static String dateKey(DateTime dt) {
    final key = localDayKey(dt);
    return '${key ~/ 10000}-${_pad((key ~/ 100) % 100)}-${_pad(key % 100)}';
  }

  static bool isSameDay(DateTime a, DateTime b) => dateKey(a) == dateKey(b);

  static String formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  /// "Hoy", "Ayer", o "5 de septiembre" para días más antiguos.
  static String formatDayLabel(DateTime dt) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(dt, now)) return 'Hoy';
    if (isSameDay(dt, yesterday)) return 'Ayer';
    final local = dt.toLocal();
    return '${local.day} de ${_months[local.month - 1]}';
  }

  static String formatHeaderDate(DateTime dt) {
    final local = dt.toLocal();
    final weekday = _weekdays[local.weekday - 1];
    final capitalized = weekday[0].toUpperCase() + weekday.substring(1);
    return '$capitalized ${local.day} de ${_months[local.month - 1]}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
