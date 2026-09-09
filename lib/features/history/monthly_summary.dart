import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/mood_type.dart';
import '../home/widgets/mood_sphere_visual.dart';

/// Ítem del resumen mensual: un estado de ánimo con su uso dentro del mes.
class MonthlySummaryItem {
  final MoodType mood;
  final int count;
  final double pct;

  const MonthlySummaryItem({required this.mood, required this.count, required this.pct});
}

/// Sección "Resumen Mensual": muestra las [_MonthlySummary.maxTopMoods] (6)
/// emociones más usadas del mes con su porcentaje REAL de uso (si quedan
/// emociones fuera del top se agrega un ítem "Otros" para que los
/// porcentajes siempre sumen 100). Arriba, burbujas de distintos tamaños
/// (área proporcional al porcentaje de uso) con el % dentro, dispuestas en
/// una nube tipo pirámide con pequeños desplazamientos para que se sientan
/// desordenadas; abajo, la leyenda con el nombre de cada emoción junto a su
/// círculo de color.
class MonthlySummary extends StatelessWidget {
  final List<MonthlySummaryItem> items;

  const MonthlySummary({super.key, required this.items});

  /// Máximo de emociones que entran en el resumen.
  static const int maxTopMoods = 6;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen Mensual',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Todavía no hay registros este mes.',
                style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
              ),
            )
          else ...[
            Center(child: _buildBubbleCloud()),
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  /// Distribuye las burbujas en filas de 1, 2, 3... (la más usada en el
  /// ápice) y las centra para formar una nube tipo pirámide. Cada burbuja
  /// recibe un pequeño desplazamiento determinístico para romper la grilla.
  Widget _buildBubbleCloud() {
    final maxPct = items.map((e) => e.pct).reduce(math.max);

    final rows = <List<MonthlySummaryItem>>[];
    var start = 0;
    for (var rowSize = 1; start < items.length; rowSize++) {
      rows.add(items.sublist(start, math.min(start + rowSize, items.length)));
      start += rowSize;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows.length; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 2 : 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < rows[row].length; i++)
                  _Bubble(
                    item: rows[row][i],
                    maxPct: maxPct,
                    jitter: Offset(
                      ((i * 7 + row * 5) % 9 - 4) * 2.4,
                      ((i * 3 + row * 4) % 7 - 3) * 1.6,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Leyenda: los nombres de las emociones en una fila (o varias si no
  /// caben), cada uno con el círculo de su color. Sin porcentajes — esos
  /// solo van dentro de las burbujas.
  Widget _buildLegend() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: [
          for (final item in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(color: item.mood.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  item.mood.label,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Burbuja con el diseño de la burbuja principal (`MoodSphereVisual`: colores,
/// brillo tipo vidrio y aura para especiales) y el porcentaje de uso adentro.
/// El tamaño crece con la raíz del porcentaje, de modo que el área es
/// proporcional al uso.
class _Bubble extends StatelessWidget {
  final MonthlySummaryItem item;
  final double maxPct;
  final Offset jitter;

  const _Bubble({required this.item, required this.maxPct, required this.jitter});

  @override
  Widget build(BuildContext context) {
    const minD = 46.0;
    const maxD = 92.0;
    final ratio = math.sqrt(item.pct / math.max(maxPct, 1));
    final d = minD + (maxD - minD) * ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Transform.translate(
        offset: jitter,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: SizedBox(
            width: d,
            height: d,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MoodSphereVisual(
                  colorsTopToBottom: [item.mood.color],
                  size: d,
                  glassEffects: true,
                ),
                Text(
                  '${item.pct.round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (d / maxD) * 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}