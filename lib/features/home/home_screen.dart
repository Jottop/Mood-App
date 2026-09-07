import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../services/date_service.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../history/calendar_screen.dart';
import '../moods/manage_moods_screen.dart';
import 'widgets/day_entry_list.dart';
import 'widgets/mood_bubble.dart';
import 'widgets/mood_picker_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Consumer2<MoodProvider, MoodCatalogProvider>(
            builder: (context, provider, catalog, _) {
              if (provider.loading || catalog.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final todaysAsc = provider.todaysEntriesAsc;
              final todaysDesc = provider.todaysEntriesDesc;
              final todaysColors = todaysAsc
                  .map((e) => catalog.byId(e.moodId).color)
                  .toList();
              final bubbleLabel = todaysAsc.isEmpty
                  ? 'Aún no registras cómo te sientes hoy'
                  : 'Ahora te sientes ${catalog.byId(todaysAsc.last.moodId).label.toLowerCase()}';

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  _Header(
                    onHistoryTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  MoodBubble(todayColors: todaysColors, label: bubbleLabel),
                  const SizedBox(height: 22),
                  const _PromptCard(),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mis estados de ánimo',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ManageMoodsScreen()),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 17, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  MoodPickerGrid(moods: catalog.moods, onSelect: provider.addEntry),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hoy',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        Row(
                          children: [
                            if (todaysDesc.isNotEmpty) ...[
                              Text(
                                '${todaysDesc.length} registro${todaysDesc.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _confirmResetToday(context, provider),
                                child: const Icon(Icons.restart_alt_rounded, size: 19, color: AppColors.inkSoft),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  DayEntryList(
                    entriesDesc: todaysDesc,
                    emptyMessage: 'Toca un estado de ánimo arriba para registrar el primero de hoy.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onHistoryTap;
  const _Header({required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu día',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              DateService.formatHeaderDate(DateTime.now()),
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: onHistoryTap,
          icon: const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.inkSoft),
          label: const Text('Historial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.card,
            side: const BorderSide(color: AppColors.cardLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmResetToday(BuildContext context, MoodProvider provider) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar los registros de hoy?'),
      content: const Text('Se eliminarán todos los estados de ánimo registrados hoy. Esta acción no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Borrar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.resetToday();
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '¿Cómo estuvo tu día?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 16.5,
          color: AppColors.creamInk,
        ),
      ),
    );
  }
}
