import 'package:flutter/material.dart';

import '../../data/mood_view_data.dart';

/// Los dos colores que necesita la burbuja de un día: la mancha del cuerpo
/// (registros en orden cronológico) y el aura (emociones especiales).
/// Compacto para compartirlo fácilmente entre pantallas y el render
/// offscreen del widget del escritorio.
class DayBubbleData {
  final List<Color> colorsTopToBottom;
  final List<Color> auraColors;
  const DayBubbleData({
    required this.colorsTopToBottom,
    this.auraColors = const [],
  });

  bool get isEmpty => colorsTopToBottom.isEmpty;
}

/// Calcula los colores de la burbuja para [date] a partir de [view] (local
/// o de amigo). `colorsTopToBottom` va de más antiguo (abajo) a más
/// reciente (arriba) y el aura solo incluye emociones especiales.
DayBubbleData dayBubbleData(MoodViewData view, DateTime date) {
  final asc = view.entriesForDateAsc(date);
  final colors = <Color>[];
  final aura = <Color>[];
  for (final entry in asc) {
    final mood = view.byId(entry.moodId);
    colors.add(mood.color);
    if (mood.isSpecial) aura.add(mood.color);
  }
  return DayBubbleData(
    colorsTopToBottom: colors.reversed.toList(),
    auraColors: aura,
  );
}