import 'package:flutter/material.dart';

import '../../../data/models/mood_entry.dart';
import '../../../data/models/mood_type.dart';
import '../../../services/date_service.dart';

/// Tarjeta individual de un registro: fondo pastel del color del estado,
/// avatar circular con el emoji, nombre destacado y hora (spec §2).
/// Cada registro es su propia tarjeta con separación, en vez de una fila
/// dentro de una lista continua — más parecido a la referencia visual.
class EntryCard extends StatelessWidget {
  final MoodEntry entry;
  final MoodType mood;
  final VoidCallback? onDelete;

  const EntryCard({super.key, required this.entry, required this.mood, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardColor = Color.lerp(mood.color, Colors.white, 0.72)!;
    final labelColor = Color.lerp(mood.color, Colors.black, 0.28)!;
    final avatarColor = Color.lerp(mood.color, Colors.white, 0.35)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.label,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: labelColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateService.formatTime(entry.timestamp),
                      style: TextStyle(fontSize: 12.5, color: labelColor.withValues(alpha: 0.65)),
                    ),
                    if (entry.isBackdated) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.history_rounded, size: 13, color: labelColor.withValues(alpha: 0.55)),
                      const SizedBox(width: 2),
                      Text(
                        'anotado después',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: labelColor.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close_rounded, size: 19, color: labelColor.withValues(alpha: 0.55)),
            ),
        ],
      ),
    );
  }
}
