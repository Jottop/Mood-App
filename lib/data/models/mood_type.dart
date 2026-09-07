import 'package:flutter/material.dart';

/// Define un estado de ánimo disponible para registrar: su id estable
/// (no cambia aunque se edite el nombre), el emoji que lo representa, el
/// nombre visible y el color asociado para la burbuja.
class MoodType {
  final String id;
  final String label;
  final String emoji;
  final Color color;

  const MoodType({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });

  MoodType copyWith({String? label, String? emoji, Color? color}) => MoodType(
        id: id,
        label: label ?? this.label,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'color': color.toARGB32(),
      };

  factory MoodType.fromJson(Map<String, dynamic> json) => MoodType(
        id: json['id'] as String,
        label: json['label'] as String,
        emoji: json['emoji'] as String,
        color: Color(json['color'] as int),
      );
}
