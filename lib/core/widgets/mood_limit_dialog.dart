import 'package:flutter/material.dart';

/// Diálogo de advertencia cuando se alcanza el máximo óptimo de emociones
/// del día ([MoodProvider.maxOptimalEntries]). Devuelve `true` si el
/// usuario confirma que quiere agregar la emoción de todas formas.
Future<bool> showMoodLimitDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Máximo óptimo alcanzado'),
      content: const Text(
        'Alcanzaste el máximo óptimo de 10 emociones por día. ¿Deseas agregar esta de todas formas?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Agregar de todas formas'),
        ),
      ],
    ),
  );
  return result ?? false;
}