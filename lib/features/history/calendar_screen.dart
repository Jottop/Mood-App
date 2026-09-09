import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/special_badge.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../home/widgets/mood_sphere_visual.dart';
import 'day_detail_screen.dart';
import 'monthly_summary.dart';

const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// Historial en formato calendario: cada día muestra una burbuja chica
/// con los colores de los estados registrados ese día (o vacía si no
/// registró nada). Tocar un día permite ver y agregar registros para esa
/// fecha, incluso si es un día anterior (spec §6).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  /// Cuenta los registros del mes visible agrupados por emoción y devuelve
  /// como máximo [MonthlySummary.maxTopMoods] con su porcentaje de uso
  /// (los estados eliminados del catálogo no se cuentan).
  List<MonthlySummaryItem> _buildMonthSummary(
    MoodProvider moodProvider,
    MoodCatalogProvider catalog,
  ) {
    final counts = <String, int>{};
    var total = 0;
    for (final e in moodProvider.allEntries) {
      if (e.timestamp.year != _visibleMonth.year || e.timestamp.month != _visibleMonth.month) {
        continue;
      }
      if (catalog.byId(e.moodId).id == '_unknown') continue;
      counts[e.moodId] = (counts[e.moodId] ?? 0) + 1;
      total += 1;
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(MonthlySummary.maxTopMoods))
        MonthlySummaryItem(
          mood: catalog.byId(e.key),
          count: e.value,
          pct: total == 0 ? 0 : e.value / total * 100,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday; // 1=lunes
    final leadingBlanks = firstWeekday - 1;
    final isCurrentMonth = _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Historial', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Consumer2<MoodProvider, MoodCatalogProvider>(
        builder: (context, moodProvider, catalog, _) {
          final monthSummary = _buildMonthSummary(moodProvider, catalog);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
                    onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final label in _weekdayLabels)
                    Expanded(
                      child: Center(
                        child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 7;
                  const spacing = 4.0;
                  const bubbleSize = 36.0;
                  const labelHeight = 22.0;
                  final cellWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
                  // El alto de cada celda depende del contenido real
                  // (burbuja + número), no de un aspect ratio adivinado
                  // — así se evita el overflow.
                  const cellHeight = bubbleSize + 4 + labelHeight;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: leadingBlanks + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) return const SizedBox.shrink();
                      final day = index - leadingBlanks + 1;
                      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
                      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                      final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
                      final entriesAsc = moodProvider.entriesForDateAsc(date);
                      final colors = entriesAsc.map((e) => catalog.byId(e.moodId).color).toList();
                      final auraColors = entriesAsc
                          .where((e) => catalog.byId(e.moodId).isSpecial)
                          .map((e) => catalog.byId(e.moodId).color)
                          .toList();
                      final hasSpecial = auraColors.isNotEmpty;

                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => DayDetailScreen(date: date)),
                                ),
                        child: Opacity(
                          opacity: isFuture ? 0.35 : 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: bubbleSize,
                                height: bubbleSize,
                                padding: const EdgeInsets.all(2),
                                child: MoodSphereVisual(
                                  colorsTopToBottom: colors.reversed.toList(),
                                  size: bubbleSize - 4,
                                  // Modo compacto: miniaturas sin blur
                                  // (la mayor parte del costo), con un solo
                                  // arco nítido + blob + rim. Evita el lag
                                  // al pintar ~37 burbujas por mes.
                                  compact: true,
                                  // Aura simple sin blur: un anillo
                                  // degradado con los colores especiales.
                                  auraColors: auraColors,
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: labelHeight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // El día de hoy se identifica por el número (y el
                                    // ícono especial si lo hay) dentro de
                                    // una píldora oscura.
                                    if (isToday)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.ink,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('$day', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                                            if (hasSpecial) ...[
                                              const SizedBox(width: 2),
                                              const SpecialBadge(size: 11, color: Colors.white),
                                            ],
                                          ],
                                        ),
                                      )
                                    else ...[
                                      Text('$day', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                                      if (hasSpecial) ...[
                                        const SizedBox(width: 2),
                                        const SpecialBadge(size: 11),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 22),
              MonthlySummary(items: monthSummary),
            ],
          );
        },
      ),
    );
  }
}
