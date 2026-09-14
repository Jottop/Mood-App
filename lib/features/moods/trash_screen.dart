import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/emoji_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/special_badge.dart';
import '../../data/models/trashed_mood.dart';
import '../../state/mood_catalog_provider.dart';

/// Papelera de emociones: las eliminadas se quedan aquí 7 días y se pueden
/// restaurar (con su id y configuración originales). Pasado ese tiempo se
/// purgan solas.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    // Carga la papelera local y purga lo vencido al abrir la pantalla.
    context.read<MoodCatalogProvider>().ensureTrashLoaded();
  }

  Future<void> _confirmEmpty(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar la papelera?'),
        content: Text(
          'Se eliminarán $count emoción${count == 1 ? '' : 'es'} para siempre. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MoodCatalogProvider>().emptyTrash();
    if (!mounted) return;
    showAppSnackBar(
      context,
      content: const Text('Papelera vaciada.'),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodCatalogProvider>(
      builder: (context, catalog, _) {
        final trash = catalog.trash;
        final canEmpty = trash.isNotEmpty;
        return Scaffold(
          backgroundColor: AppColors.bgBottom,
          appBar: AppBar(
            backgroundColor: AppColors.bgBottom,
            elevation: 0,
            title: const Text('Papelera',
                style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
            iconTheme: const IconThemeData(color: AppColors.ink),
            actions: [
              IconButton(
                onPressed: canEmpty ? () => _confirmEmpty(trash.length) : null,
                tooltip: 'Vaciar papelera',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 22,
                  color: canEmpty ? AppColors.inkSoft : AppColors.cardLine,
                ),
              ),
            ],
          ),
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bgTop, AppColors.bgBottom],
              ),
            ),
            child: trash.isEmpty ? const _EmptyTrash() : _trashList(trash),
          ),
        );
      },
    );
  }

  Widget _trashList(List<TrashedMood> trash) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: AppColors.creamInk),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las emociones eliminadas se guardan aquí 7 días. Al vencer el plazo se borran solas. Puedes restaurarlas cuando quieras.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.creamInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in trash) ...[
          _TrashRow(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_rounded, size: 42, color: AppColors.inkSoft),
            SizedBox(height: 12),
            Text(
              'Tu papelera está vacía.',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            SizedBox(height: 4),
            Text(
              'Las emociones que elimines se quedarán aquí 7 días por si quieres recuperarlas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  final TrashedMood item;

  const _TrashRow({required this.item});

  static const _retention = Duration(days: 7);

  /// Texto de los días restantes antes de la purga automática.
  String _remainingLabel(DateTime now) {
    final remaining = item.deletedAt.add(_retention).difference(now);
    if (remaining.inDays >= 1) {
      return 'Se eliminará en ${remaining.inDays} día${remaining.inDays == 1 ? '' : 's'}';
    }
    if (remaining.inHours >= 1) {
      return 'Se eliminará en ${remaining.inHours} hora${remaining.inHours == 1 ? '' : 's'}';
    }
    return 'Se eliminará hoy';
  }

  @override
  Widget build(BuildContext context) {
    final mood = item.mood;
    final cardBg = Color.lerp(mood.color, Colors.white, 0.78)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: mood.color, shape: BoxShape.circle),
            child: Text(mood.emoji,
                style: const TextStyle(fontSize: 22, fontFamilyFallback: kEmojiFontFallback)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mood.label,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                    if (mood.isSpecial) ...[
                      const SizedBox(width: 6),
                      const SpecialBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _remainingLabel(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<MoodCatalogProvider>().restoreMood(mood.id),
            tooltip: 'Restaurar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.restore_rounded, size: 22, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}