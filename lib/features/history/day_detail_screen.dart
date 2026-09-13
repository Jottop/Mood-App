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

/// El pager del detalle usa SOLO 3 páginas alrededor del día visible
/// (anterior / actual / siguiente): al deslizar se cambia [DayDetailScreen]
/// interno y se vuelve a la página central. El offset de scroll nunca crece
/// (siempre ±1 viewport), así que el swipe atrás es ilimitado y a la derecha
/// se frena en el día actual. Nunca se llega a offsets ni índices enormes.
///
/// El rebase NO ocurre a mitad del gesto (ahí `onPageChanged` solo marca la
/// dirección pendiente): se aplica cuando el scroll se ASIENTA (dedo
/// levantado / inercia terminada), así el contenido no cambia bajo el dedo
/// y el salto a la página central queda invisible.

/// Detalle de un día cualquiera. Permite ver sus registros y, si no es un
/// día futuro ni una vista de solo lectura (amigo), agregar más — quedan
/// marcados como "anotados después" porque se registraron otro día distinto
/// al que corresponden (spec §6). Se desliza a izquierda/derecha para
/// recorrer días, solo hasta el día actual.
class DayDetailScreen extends StatefulWidget {
  final DateTime date;

  /// Fuente de datos. Si es null, se resuelve desde los providers locales
  /// (modo "yo"): comportamiento reactivo idéntico al anterior.
  final MoodViewData? view;

  /// True en la vista de un amigo: sin grilla para agregar, sin reiniciar
  /// el día y sin editar los registros.
  final bool readOnly;

  const DayDetailScreen({super.key, required this.date, this.view, this.readOnly = false});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  /// Día visible (siempre a medianoche local); las páginas del pager son
  /// [current - 1], [current] y [current + 1].
  late DateTime _currentDay;
  late final PageController _controller;

  /// Dirección del día a la que se deslizó (0, ±1), pendiente de aplicar
  /// recién cuando el scroll se asiente.
  int _pendingDirection = 0;

  @override
  void initState() {
    super.initState();
    _currentDay = _dayOnly(widget.date);
    // Siempre arrancamos en la página central (1 de 3). Nunca hay rebase
    // inicial: el offset queda en una sola página, sin importar hace cuánto
    // el día tocado.
    _controller = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _dateForIndex(int index) {
    final d = _currentDay;
    return DateTime(d.year, d.month, d.day + (index - 1));
  }

  bool get _atToday {
    final d = _currentDay;
    final today = DateTime.now();
    return DateService.isSameDay(d, today);
  }

  /// Cuando ya estamos en el día actual no existe página "siguiente": con
  /// itemCount 2 el swipe a la derecha rebota en el borde (sin una página
  /// futura que renderizar) y [onPageChanged] nunca llega al índice 2.
  int get _pageCount => _atToday ? 2 : 3;

  /// Solo registra la dirección del swipe; el cambio de día NO se hace acá
  /// porque este evento dispara al cruzar la mitad de la pantalla, con el
  /// dedo todavía abajo: rebasear ahí hace que la página salte brusca por
  /// delante de la mitad del gesto.
  void _onPageChanged(int index) {
    if (index == 1) {
      _pendingDirection = 0;
      return;
    }
    if (index == 0) {
      _pendingDirection = -1;
      return;
    }
    // index == 2: solo existe 1 día "adelante" y se frena en hoy. Defensa
    // extra por si el itemCount llegara a incluir el índice (no debería).
    if (_atToday) {
      _pendingDirection = 0;
      _controller.jumpToPage(1);
      return;
    }
    _pendingDirection = 1;
  }

  /// Aplica el día nuevo y rebasa al centro cuando el scroll ya se asentó:
  /// el gesto terminó, así que el salto a la página central no se ve y la
  /// página central pasa a mostrar (con el mismo contenido que venía de la
  /// página lateral) el día recién elegido.
  void _applyPendingRebase() {
    if (_pendingDirection == 0) return;
    final direction = _pendingDirection;
    _pendingDirection = 0;
    final d = _currentDay;
    if (direction > 0 && _atToday) return;
    _currentDay = DateTime(d.year, d.month, d.day + direction);
    setState(() {});
    // Sin animación: al estar idle no interfiere con ningún gesto.
    _controller.jumpToPage(1);
  }

  /// Título de la barra para el día visible: "Hoy", "Ayer" o "d de mes".
  String _titleFor(DateTime date) {
    final today = DateTime.now();
    return DateService.isSameDay(date, today) ? 'Hoy' : DateService.formatDayLabel(date);
  }

  @override
  Widget build(BuildContext context) {
    // En modo amigo [view] es la info congelada del otro usuario (no hay
    // providers locales que escuchar). En modo "yo" siempre usamos la vía
    // reactiva (Consumer2): aunque el calendario pase un `view` local, si
    // nos quedáramos con esa instancia estática la pantalla no se
    // reconstruiría al agregar emociones.
    if (widget.readOnly) {
      return _buildScaffold(context, widget.view!);
    }
    return Consumer2<MoodProvider, MoodCatalogProvider>(
      builder: (context, provider, catalog, _) =>
          _buildScaffold(context, LocalMoodViewData(provider: provider, catalog: catalog)),
    );
  }

  Widget _buildScaffold(BuildContext context, MoodViewData data) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: Text(
          _titleFor(_currentDay),
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          // Solo el scroll del pager (notifications de las listas internas
          // de cada día llegaron con mayor profundidad). Al asentarse el
          // swipe recién ahí cambiamos de día y rebasamos al centro.
          if (notification.depth == 0) _applyPendingRebase();
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          // Offset siempre acotado (±1 viewport): al deslizar se cambia el día
          // y se rebasa a la página central. Cuando se llega a hoy no hay página
          // "siguiente" (itemCount 2) y el swipe a la derecha rebota en el borde.
          itemCount: _pageCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => _buildDay(context, _dateForIndex(index), data),
        ),
      ),
    );
  }

  Widget _buildDay(BuildContext context, DateTime date, MoodViewData data) {
    final today = DateTime.now();
    final isToday = DateService.isSameDay(date, today);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    final isEditable = !widget.readOnly && !isFuture;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
      children: [
        // La burbuja del día SIEMPRE se muestra: si no hubo
        // registros aparece vacía pero con el mismo diseño (vidrio
        // + sheen de burbuja de jabón) y animaciones (flotación +
        // transición al cambiar) de la burbuja principal. El
        // espacio fijo para el aura lo reserva el propio widget.
        // Key por día: al rebasar el pager, el State se recrea y la
        // burbuja del día nuevo aparece al instante (sin que la del
        // día anterior haga su transición de fundido). Agregar una
        // emoción dentro del mismo día sí la conserva y anima.
        Center(
          child: FloatingSphere(
            key: ValueKey(date),
            colors: _entriesAscColors(data, date),
            // Aura con las emociones especiales de ese día.
            auraColors: _entriesAscSpecial(data, date),
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
            moodsCount: _dayCounts(data, date),
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
              if (data.entriesForDateDesc(date).isNotEmpty && !widget.readOnly)
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
          readOnly: widget.readOnly,
          emptyMessage: isFuture
              ? 'Todavía no ha llegado este día.'
              : 'No hay registros para este día. Puedes agregar uno arriba.',
        ),
      ],
    );
  }

  List<Color> _entriesAscColors(MoodViewData data, DateTime date) =>
      data.entriesForDateAsc(date).map((e) => data.byId(e.moodId).color).toList().reversed.toList();

  List<Color> _entriesAscSpecial(MoodViewData data, DateTime date) => data
      .entriesForDateAsc(date)
      .where((e) => data.byId(e.moodId).isSpecial)
      .map((e) => data.byId(e.moodId).color)
      .toList();

  /// Cuántas veces está registrada cada emoción en este día, para el
  /// contador de la grilla de selección.
  Map<String, int> _dayCounts(MoodViewData data, DateTime date) {
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