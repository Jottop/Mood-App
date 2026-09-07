/// Un registro individual: qué estado de ánimo y a qué momento
/// corresponde. No se reemplaza al agregar uno nuevo; cada uno se
/// conserva (ver spec §2).
class MoodEntry {
  final String id;
  final String moodId;

  /// El día/hora al que "pertenece" el registro (normalmente ahora, pero
  /// puede ser un día anterior si se anotó retroactivamente).
  final DateTime timestamp;

  /// El momento real en que el usuario tocó el botón para crear este
  /// registro. Si es de un día distinto al de [timestamp], significa que
  /// se anotó a posteriori (ver spec §6, historial).
  final DateTime loggedAt;

  const MoodEntry({
    required this.id,
    required this.moodId,
    required this.timestamp,
    required this.loggedAt,
  });

  bool get isBackdated =>
      loggedAt.year != timestamp.year || loggedAt.month != timestamp.month || loggedAt.day != timestamp.day;

  Map<String, dynamic> toJson() => {
        'id': id,
        'moodId': moodId,
        'timestamp': timestamp.toIso8601String(),
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        moodId: json['moodId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        // loggedAt es nuevo; si un registro viejo no lo tiene, asumimos
        // que se anotó el mismo día (comportamiento anterior).
        loggedAt: json['loggedAt'] != null
            ? DateTime.parse(json['loggedAt'] as String)
            : DateTime.parse(json['timestamp'] as String),
      );
}
