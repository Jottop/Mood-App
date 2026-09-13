import 'mood_type.dart';

/// Emoción eliminada que vive en la papelera (local). Conserva el estado de
/// ánimo completo para poder restaurarlo sin cambios, junto con el momento
/// en que se eliminó (para la cuenta regresiva de purga automática).
class TrashedMood {
  final MoodType mood;
  final DateTime deletedAt;

  const TrashedMood({required this.mood, required this.deletedAt});

  Map<String, dynamic> toJson() => {
        'mood': mood.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashedMood.fromJson(Map<String, dynamic> json) => TrashedMood(
        mood: MoodType.fromJson(json['mood'] as Map<String, dynamic>),
        deletedAt: DateTime.parse(json['deletedAt'] as String),
      );
}