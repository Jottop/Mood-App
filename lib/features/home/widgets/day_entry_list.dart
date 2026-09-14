import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/undo_progress_bar.dart';
import '../../../data/models/mood_entry.dart';
import '../../../data/models/mood_type.dart';
import '../../../data/mood_view_data.dart';
import '../../../state/mood_catalog_provider.dart';
import '../../../state/mood_provider.dart';
import 'entry_card.dart';

/// Duración del aviso de "Registro eliminado" con su barra de progreso.
const _undoDuration = Duration(seconds: 4);

/// Pila de tarjetas de color con los registros de un día, de más
/// reciente a más antiguo (spec §2). Muestra un mensaje guía si aún no
/// hay registros.
///
/// Reordenable: mantener presionada una tarjeta la mueve por la lista
/// (misma función que en la gestión de estados); el nuevo orden se persiste
/// reasignando los timestamps del día.
///
/// Borrado rápido: tocar la "x" saca la tarjeta (animación de salida),
/// elimina el registro al instante y muestra un aviso con "Deshacer" y una
/// barra que se vacía en [duration]; si no se deshace, el borrado queda
/// definitivo. Cada tarjeta se envuelve en [_AnimatedEntryCard]: al
/// aparecer (registro nuevo) entra con un fundido + deslizamiento, y al
/// borrarse se sale con la misma animación invertida.
class DayEntryList extends StatelessWidget {
  final List<MoodEntry> entriesDesc;
  final String emptyMessage;

  /// Día al que pertenecen estos registros (hoy en el Home, la fecha en el
  /// detalle del día). Se usa para reordenar dentro de ese día.
  final DateTime date;

  /// Fuente de datos (modo amigo = snapshot de solo lectura). Si es null,
  /// se resuelve desde los providers locales (mismo comportamiento previo).
  final MoodViewData? view;

  /// True en la vista de un amigo: sin botón de "x", sin reordenar y sin
  /// aviso de deshacer.
  final bool readOnly;

  const DayEntryList({
    super.key,
    required this.entriesDesc,
    required this.date,
    this.emptyMessage = 'Todavía no hay registros para este día.',
    this.view,
    this.readOnly = false,
  });

  /// Borra el registro de inmediato y ofrece deshacer con una barra de
  /// progreso de [_undoDuration]. El registro se elimina YA del proveedor;
  /// deshacer lo restaura con su mismo id y timestamp (misma posición).
  void _deleteWithUndo(BuildContext context, MoodEntry entry) {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<MoodProvider>();
    provider.deleteEntry(entry.id);

    showAppSnackBar(
      context,
      content: UndoProgressBar(
        duration: _undoDuration,
        // Al terminar la barra se cierra el aviso: así la desaparición a los
        // 4s está garantizada aunque el timer del framework tarde.
        onFinished: () => messenger.hideCurrentSnackBar(),
      ),
      action: SnackBarAction(
        label: 'Deshacer',
        textColor: AppColors.ink,
        onPressed: () => provider.restoreEntry(entry),
      ),
    );
  }

  void _handleReorder(BuildContext context, int oldIndex, int newIndex) {
    final list = [...entriesDesc];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    context
        .read<MoodProvider>()
        .reorderDayEntries(date, [for (final e in list) e.id]);
  }

  @override
  Widget build(BuildContext context) {
    if (entriesDesc.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardLine),
        ),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.5),
        ),
      );
    }

    final MoodViewData data = view ??
        LocalMoodViewData(
          provider: context.watch<MoodProvider>(),
          catalog: context.watch<MoodCatalogProvider>(),
        );

    // Modo amigo (solo lectura): lista plana sin "x", sin agarre de
    // reordenado y sin animación de borrado.
    if (readOnly) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entriesDesc.length,
        itemBuilder: (context, index) {
          final entry = entriesDesc[index];
          return Padding(
            key: ValueKey(entry.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: EntryCard(entry: entry, mood: data.byId(entry.moodId)),
          );
        },
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Material(
          color: Colors.transparent,
          elevation: 0,
          child: RepaintBoundary(
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.03).animate(animation),
              child: child,
            ),
          ),
        ),
      ),
      itemCount: entriesDesc.length,
      onReorderItem: (oldIndex, newIndex) => _handleReorder(context, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final entry = entriesDesc[index];
        return Padding(
          key: ValueKey(entry.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: _AnimatedEntryCard(
              entry: entry,
              mood: data.byId(entry.moodId),
              onDeleted: () => _deleteWithUndo(context, entry),
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta que anima su entrada (al montarse) y su salida (al borrarse):
/// fundido + deslizamiento vertical de 14px, con el mismo eje de control
/// para ambos sentidos — aparece de 0 → 1 y se va de 1 → 0.
class _AnimatedEntryCard extends StatefulWidget {
  final MoodEntry entry;
  final MoodType mood;
  final VoidCallback onDeleted;

  const _AnimatedEntryCard({
    required this.entry,
    required this.mood,
    required this.onDeleted,
  });

  @override
  State<_AnimatedEntryCard> createState() => _AnimatedEntryCardState();
}

class _AnimatedEntryCardState extends State<_AnimatedEntryCard>
    with SingleTickerProviderStateMixin {
  // Empieza oculto (0) y avanza a visible (1): la entrada anima al
  // montarse; la salida invierte de 1 → 0 antes de borrar del proveedor.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 0,
  )..forward();

  bool _removing = false;

  Future<void> _handleDelete() async {
    if (_removing) return;
    setState(() => _removing = true);
    await _controller.reverse();
    if (mounted) widget.onDeleted();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: EntryCard(
        entry: widget.entry,
        mood: widget.mood,
        onDelete: _handleDelete,
      ),
    );
  }
}