import 'package:flutter/material.dart';

import '../../core/emoji_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/percentages.dart';
import '../../core/widgets/special_badge.dart';
import '../../data/models/mood_entry.dart';
import '../../data/mood_view_data.dart';

/// Desglose de porcentajes por estado de ánimo de un día. Muestra en una
/// fila cada emoción con su ícono y su porción del día.
///
/// Es un widget público porque lo usan el detalle de un día propio y el
/// perfil de un amigo (comparten la lógica exacta).
class MoodSummary extends StatelessWidget {
  final List<MoodEntry> entriesAsc;
  final MoodViewData view;

  const MoodSummary({super.key, required this.entriesAsc, required this.view});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in entriesAsc) {
      counts[e.moodId] = (counts[e.moodId] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // Porcentajes redondeados que SIEMPRE suman 100 (método del resto
    // mayor), en el mismo orden que el desglose.
    final pcts = distributePercentages([for (final e in sorted) e.value]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < sorted.length; i++)
            _SummaryItem(entry: sorted[i], pct: pcts[i], view: view),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final MapEntry<String, int> entry;
  final int pct;
  final MoodViewData view;

  const _SummaryItem({required this.entry, required this.pct, required this.view});

  @override
  Widget build(BuildContext context) {
    final mood = view.byId(entry.key);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El ícono va dentro de un círculo con el color de la emoción
            // para leer de un vistazo qué tono le corresponde.
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mood.color,
                shape: BoxShape.circle,
              ),
              child: Text(mood.emoji,
                  style: const TextStyle(fontSize: 19, fontFamilyFallback: kEmojiFontFallback)),
            ),
            if (mood.isSpecial) ...[
              const SizedBox(width: 1),
              const SpecialBadge(size: 12),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$pct%',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ],
    );
  }
}