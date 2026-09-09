import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/percentages.dart';
import '../../core/widgets/mood_limit_dialog.dart';
import '../../core/widgets/special_badge.dart';
import '../../data/models/mood_entry.dart';
import '../../services/date_service.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../home/widgets/day_entry_list.dart';
import '../home/widgets/mood_bubble.dart';
import '../home/widgets/mood_picker_grid.dart';

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
            builder: (context, provider, catalog, _) {
              final entriesDesc = provider.entriesForDateDesc(date);
              final entriesAsc = provider.entriesForDateAsc(date);
              // Cuántas veces está registrada cada emoción en este día,
              // para el contador de la grilla de selección.
              final dayCounts = <String, int>{};
              for (final e in entriesAsc) {
                dayCounts[e.moodId] = (dayCounts[e.moodId] ?? 0) + 1;
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  // La burbuja del día SIEMPRE se muestra: si no hubo
                  // registros aparece vacía pero con el mismo diseño (vidrio
                  // + sheen de burbuja de jabón) y animaciones (flotación +
                  // transición al cambiar) de la burbuja principal. El
                  // espacio fijo para el aura lo reserva el propio widget.
                  Center(
                    child: FloatingSphere(
                      colors: entriesAsc
                          .map((e) => catalog.byId(e.moodId).color)
                          .toList()
                          .reversed
                          .toList(),
                      // Aura con las emociones especiales de ese día.
                      auraColors: entriesAsc
                          .where((e) => catalog.byId(e.moodId).isSpecial)
                          .map((e) => catalog.byId(e.moodId).color)
                          .toList(),
                      size: 180,
                      floatAmplitude: 12,
                    ),
                  ),
                  if (entriesAsc.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MoodSummary(entriesAsc: entriesAsc, catalog: catalog),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 20),
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
                      moodsCount: dayCounts,
                      onSelect: (moodId) => _selectMoodForDate(context, provider, date, isToday, moodId),
                    ),
                    const SizedBox(height: 18),
                  ],
Padding(
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registros',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    Row(
                      children: [
                        if (entriesDesc.isNotEmpty && !isFuture) ...[
                          Text(
                            '${entriesDesc.length} registro${entriesDesc.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _confirmResetDay(context, provider, date),
                            child: const Icon(Icons.restart_alt_rounded, size: 24, color: AppColors.inkSoft),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
                  DayEntryList(
                    entriesDesc: entriesDesc,
                    date: date,
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

Future<void> _selectMoodForDate(
  BuildContext context,
  MoodProvider provider,
  DateTime date,
  bool isToday,
  String moodId,
) async {
  if (provider.entriesForDateAsc(date).length >= MoodProvider.maxOptimalEntries) {
    final proceed = await showMoodLimitDialog(context);
    if (!proceed) return;
  }
  if (isToday) {
    provider.addEntry(moodId);
  } else {
    provider.addEntryForDate(moodId, date);
  }
}

Future<void> _confirmResetDay(BuildContext context, MoodProvider provider, DateTime date) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar los registros de este día?'),
      content: const Text(
        'Se eliminarán todos los estados de ánimo registrados para este día. Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Borrar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.resetDay(date);
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

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
            _SummaryItem(entry: sorted[i], pct: pcts[i], catalog: catalog),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final MapEntry<String, int> entry;
  final int pct;
  final MoodCatalogProvider catalog;

  const _SummaryItem({required this.entry, required this.pct, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final mood = catalog.byId(entry.key);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 26)),
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
