import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/mood_entry.dart';
import '../../services/date_service.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../home/widgets/day_entry_list.dart';
import '../home/widgets/mood_picker_grid.dart';
import '../home/widgets/mood_sphere_visual.dart';

/// Detalle de un día cualquiera del calendario. Permite ver sus
/// registros y, si no es un día futuro, agregar más — quedan marcados
/// como "anotados después" porque se registraron otro día distinto al
/// que corresponden (spec §6).
class DayDetailScreen extends StatelessWidget {
  final DateTime date;
  const DayDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = DateService.isSameDay(date, today);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: Text(
          isToday ? 'Hoy' : DateService.formatDayLabel(date),
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Consumer2<MoodProvider, MoodCatalogProvider>(
        builder: (context, moodProvider, catalog, _) {
          final entriesDesc = moodProvider.entriesForDateDesc(date);
          final entriesAsc = moodProvider.entriesForDateAsc(date);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              if (entriesAsc.isNotEmpty) ...[
                Center(
                  child: MoodSphereVisual(
                    colorsTopToBottom:
                        entriesAsc.map((e) => catalog.byId(e.moodId).color).toList().reversed.toList(),
                    size: 180,
                  ),
                ),
                const SizedBox(height: 16),
                _MoodSummary(entriesAsc: entriesAsc, catalog: catalog),
                const SizedBox(height: 20),
              ],
              if (!isFuture) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: Text(
                    'Agregar un estado para este día',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                  ),
                ),
                MoodPickerGrid(
                  moods: catalog.moods,
                  onSelect: (moodId) {
                    if (isToday) {
                      moodProvider.addEntry(moodId);
                    } else {
                      moodProvider.addEntryForDate(moodId, date);
                    }
                  },
                ),
                const SizedBox(height: 18),
              ],
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  'Registros',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              DayEntryList(
                entriesDesc: entriesDesc,
                emptyMessage: isFuture
                    ? 'Todavía no ha llegado este día.'
                    : 'No hay registros para este día. Puedes agregar uno arriba.',
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Resumen del día: desglose de porcentajes por estado de ánimo.
/// Muestra en una fila cada emoción con su ícono y su porción del día.
class _MoodSummary extends StatelessWidget {
  final List<MoodEntry> entriesAsc;
  final MoodCatalogProvider catalog;

  const _MoodSummary({required this.entriesAsc, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in entriesAsc) {
      counts[e.moodId] = (counts[e.moodId] ?? 0) + 1;
    }
    final total = entriesAsc.length;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          for (final entry in sorted) _SummaryItem(entry: entry, total: total, catalog: catalog),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final MapEntry<String, int> entry;
  final int total;
  final MoodCatalogProvider catalog;

  const _SummaryItem({required this.entry, required this.total, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final mood = catalog.byId(entry.key);
    final pct = total == 0 ? 0 : (entry.value * 100 / total).round();

    return Column(
      children: [
        Text(mood.emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 2),
        Text(
          '$pct%',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ],
    );
  }
}
