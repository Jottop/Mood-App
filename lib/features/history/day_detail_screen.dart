import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mood_limit_dialog.dart';
import '../../data/mood_view_data.dart';
import '../../services/date_service.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../home/widgets/day_entry_list.dart';
import '../home/widgets/mood_bubble.dart';
import '../home/widgets/mood_picker_grid.dart';
import 'mood_summary.dart';

/// Detalle de un día cualquiera. Permite ver sus registros y, si no es un
/// día futuro ni una vista de solo lectura (amigo), agregar más — quedan
/// marcados como "anotados después" porque se registraron otro día distinto
/// al que corresponden (spec §6).
class DayDetailScreen extends StatelessWidget {
  final DateTime date;

  /// Fuente de datos. Si es null, se resuelve desde los providers locales
  /// (modo "yo"): comportamiento reactivo idéntico al anterior.
  final MoodViewData? view;

  /// True en la vista de un amigo: sin grilla para agregar, sin reiniciar
  /// el día y sin editar los registros.
  final bool readOnly;

  const DayDetailScreen({super.key, required this.date, this.view, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    // En modo amigo [view] es la info congelada del otro usuario (no hay
    // providers locales que escuchar). En modo "yo" siempre usamos la vía
    // reactiva (Consumer2): aunque el calendario pase un `view` local, si
    // nos quedáramos con esa instancia estática la pantalla no se
    // reconstruiría al agregar emociones.
    if (readOnly) {
      return _buildScaffold(context, view!);
    }
    return Consumer2<MoodProvider, MoodCatalogProvider>(
      builder: (context, provider, catalog, _) =>
          _buildScaffold(context, LocalMoodViewData(provider: provider, catalog: catalog)),
    );
  }

  Widget _buildScaffold(BuildContext context, MoodViewData data) {
    final today = DateTime.now();
    final isToday = DateService.isSameDay(date, today);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    final isEditable = !readOnly && !isFuture;

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
        children: [
          // La burbuja del día SIEMPRE se muestra: si no hubo
          // registros aparece vacía pero con el mismo diseño (vidrio
          // + sheen de burbuja de jabón) y animaciones (flotación +
          // transición al cambiar) de la burbuja principal. El
          // espacio fijo para el aura lo reserva el propio widget.
          Center(
            child: FloatingSphere(
              colors: entriesAscColors(data),
              // Aura con las emociones especiales de ese día.
              auraColors: entriesAscSpecial(data),
              size: 180,
              floatAmplitude: 12,
            ),
          ),
          if (data.entriesForDateAsc(date).isNotEmpty) ...[
            const SizedBox(height: 16),
            MoodSummary(entriesAsc: data.entriesForDateAsc(date), view: data),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 20),
          if (isEditable) ...[
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                'Agregar un estado para este día',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
              ),
            ),
            MoodPickerGrid(
              moods: data.catalogMoods,
              moodsCount: dayCounts(data),
              onSelect: (moodId) => _selectMoodForDate(context, date, isToday, moodId),
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
                if (data.entriesForDateDesc(date).isNotEmpty && !readOnly)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${data.entriesForDateDesc(date).length} registro${data.entriesForDateDesc(date).length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                        if (!isFuture) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _confirmResetDay(context, date),
                            child: const Icon(Icons.restart_alt_rounded, size: 24, color: AppColors.inkSoft),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          DayEntryList(
            entriesDesc: data.entriesForDateDesc(date),
            date: date,
            view: data,
            readOnly: readOnly,
            emptyMessage: isFuture
                ? 'Todavía no ha llegado este día.'
                : 'No hay registros para este día. Puedes agregar uno arriba.',
          ),
        ],
      ),
    );
  }

  List<Color> entriesAscColors(MoodViewData data) =>
      data.entriesForDateAsc(date).map((e) => data.byId(e.moodId).color).toList().reversed.toList();

  List<Color> entriesAscSpecial(MoodViewData data) => data.entriesForDateAsc(date)
      .where((e) => data.byId(e.moodId).isSpecial)
      .map((e) => data.byId(e.moodId).color)
      .toList();

  /// Cuántas veces está registrada cada emoción en este día, para el
  /// contador de la grilla de selección.
  Map<String, int> dayCounts(MoodViewData data) {
    final counts = <String, int>{};
    for (final e in data.entriesForDateAsc(date)) {
      counts[e.moodId] = (counts[e.moodId] ?? 0) + 1;
    }
    return counts;
  }
}

Future<void> _selectMoodForDate(
  BuildContext context,
  DateTime date,
  bool isToday,
  String moodId,
) async {
  final provider = context.read<MoodProvider>();
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

Future<void> _confirmResetDay(BuildContext context, DateTime date) async {
  final provider = context.read<MoodProvider>();
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