import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../services/date_service.dart';
import '../../state/mood_provider.dart';
import '../home/widgets/day_entry_list.dart';

/// Historial básico: un día por sección, con sus registros (spec §6).
/// No incluye estadísticas todavía — solo lo necesario para que el
/// usuario pueda repasar días anteriores.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Historial', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Consumer<MoodProvider>(
        builder: (context, provider, _) {
          final groups = provider.historyByDay;
          final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

          if (keys.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Todavía no hay días anteriores registrados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final entries = groups[key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateService.formatDayLabel(entries.first.timestamp),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                          Text(
                            '${entries.length} registro${entries.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    DayEntryList(entriesDesc: entries, date: entries.first.timestamp),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
