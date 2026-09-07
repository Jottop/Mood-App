import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/mood_entry.dart';
import '../../../state/mood_catalog_provider.dart';
import '../../../state/mood_provider.dart';
import 'entry_card.dart';

/// Pila de tarjetas de color con los registros de un día, de más
/// reciente a más antiguo (spec §2). Muestra un mensaje guía si aún no
/// hay registros.
class DayEntryList extends StatelessWidget {
  final List<MoodEntry> entriesDesc;
  final String emptyMessage;

  const DayEntryList({
    super.key,
    required this.entriesDesc,
    this.emptyMessage = 'Todavía no hay registros para este día.',
  });

  Future<void> _confirmDelete(BuildContext context, MoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este registro?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<MoodProvider>().deleteEntry(entry.id);
    }
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

    final catalog = context.watch<MoodCatalogProvider>();

    return Column(
      children: [
        for (var i = 0; i < entriesDesc.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          EntryCard(
            entry: entriesDesc[i],
            mood: catalog.byId(entriesDesc[i].moodId),
            onDelete: () => _confirmDelete(context, entriesDesc[i]),
          ),
        ],
      ],
    );
  }
}
