import 'package:flutter/material.dart';

/// Define un estado de ánimo disponible para registrar: su id estable
/// (no cambia aunque se edite el nombre), el emoji que lo representa, el
/// nombre visible, el color asociado para la burbuja y si es una emoción
/// "especial" (se resalta con un aura sutil alrededor de la burbuja).
class MoodType {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final bool isSpecial;

  const MoodType({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    this.isSpecial = false,
  });

  MoodType copyWith({String? label, String? emoji, Color? color, bool? isSpecial}) => MoodType(
        id: id,
        label: label ?? this.label,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        isSpecial: isSpecial ?? this.isSpecial,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'color': color.toARGB32(),
        'isSpecial': isSpecial,
      };

  factory MoodType.fromJson(Map<String, dynamic> json) => MoodType(
        id: json['id'] as String,
        label: json['label'] as String,
        emoji: json['emoji'] as String,
        color: Color(json['color'] as int),
        // Retrocompatible: catálogos guardados antes de existir la bandera.
        isSpecial: json['isSpecial'] as bool? ?? false,
      );
}