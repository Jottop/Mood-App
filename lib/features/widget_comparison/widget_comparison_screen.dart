import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/mood_view_data.dart';
import '../../state/friends_provider.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import 'mood_comparison_scene.dart';
import 'widget_cache_store.dart';
import 'widget_comparison_service.dart';

/// Configuración del widget de comparación del escritorio: elegir hasta 2
/// amigos cuya burbuja se compara con la mía, la disposición
/// (horizontal/vertical), una preview en vivo de la escena y pedirle al
/// sistema instalar el AppWidget (pin nativo, Android 8+).
class WidgetComparisonScreen extends StatefulWidget {
  const WidgetComparisonScreen({super.key});

  @override
  State<WidgetComparisonScreen> createState() => _WidgetComparisonScreenState();
}

class _WidgetComparisonScreenState extends State<WidgetComparisonScreen> {
  bool? _pinSupported;

  @override
  void initState() {
    super.initState();
    HomeWidget.isRequestPinWidgetSupported().then((ok) {
      if (mounted) setState(() => _pinSupported = ok);
    });
  }

  Future<void> _pinWidget(BuildContext context) async {
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: 'com.example.mood_app.MoodComparisonProvider',
    );
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      content: const Text('Elige la posición del widget en tu escritorio.'),
      duration: const Duration(seconds: 3),
    );
  }

  void _toggleFriend(WidgetComparisonService service, String id, String name) {
    final ids = [...service.friendIds];
    final names = [...service.friendNames];
    final index = ids.indexOf(id);
    if (index >= 0) {
      ids.removeAt(index);
      names.removeAt(index);
    } else {
      if (ids.length >= 2) {
        showAppSnackBar(
          context,
          content: const Text('Máximo 2 amigos: el widget muestra hasta 3 burbujas.'),
        );
        return;
      }
      ids.add(id);
      names.add(name);
    }
    service.setFriends(ids, names);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WidgetComparisonService>();
    final friends = context.watch<FriendsProvider>().friends;
    final moodProvider = context.read<MoodProvider>();
    final catalog = context.read<MoodCatalogProvider>();

    final localView = LocalMoodViewData(provider: moodProvider, catalog: catalog);
    final now = DateTime.now();
    final bubbles = <DayBubbleData>[
      dayBubbleData(localView, now),
    ];
    final labels = <String>['Yo'];
    for (var i = 0; i < service.friendIds.length; i++) {
      final view = service.friendView(service.friendIds[i]);
      bubbles.add(
        view == null
            ? const DayBubbleData(colorsTopToBottom: [])
            : dayBubbleData(view, now),
      );
      labels.add(service.friendNames[i]);
    }

    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text(
          'Widget de comparación',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
          children: [
            const _IntroCard(),
            const SizedBox(height: 20),
            const Text(
              'Así se verá',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            MoodComparisonScene(
              bubbles: bubbles,
              labels: labels,
              layout: service.layout,
            ),
            const SizedBox(height: 12),
            if (service.lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '⚠ ${service.lastError}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFB25E2C)),
                ),
              ),
            if (service.lastRenderedAt != null)
              Text(
                'Última actualización: ${_formatTime(service.lastRenderedAt!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            const SizedBox(height: 20),
            const Text(
              'Disposición',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Horizontal',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  selected: service.layout == WidgetLayout.horizontal,
                  onSelected: (_) =>
                      service.setLayout(WidgetLayout.horizontal),
                  selectedColor: const Color(0xFFD3E4F6),
                  backgroundColor: AppColors.card,
                  avatar: const Icon(Icons.swap_horiz_rounded,
                      size: 15, color: AppColors.inkSoft),
                  side: const BorderSide(color: AppColors.cardLine),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                ChoiceChip(
                  label: const Text('Vertical',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  selected: service.layout == WidgetLayout.vertical,
                  onSelected: (_) => service.setLayout(WidgetLayout.vertical),
                  selectedColor: const Color(0xFFD3E4F6),
                  backgroundColor: AppColors.card,
                  avatar: const Icon(Icons.swap_vert_rounded,
                      size: 15, color: AppColors.inkSoft),
                  side: const BorderSide(color: AppColors.cardLine),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ],
            ),
            if (service.layout == WidgetLayout.vertical) ...[
              const SizedBox(height: 6),
              const Text(
                'En vertical, estira el widget en la pantalla de inicio para que las burbujas se vean apiladas y grandes.',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              '¿A quién comparas contigo?',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elegí hasta 2 amigos: la 1.ª burbuja es siempre tuya (2 o 3 burbujas en total).',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            if (friends.isEmpty)
              const _NoFriendsHint()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final friendProfile in friends)
                    ChoiceChip(
                      label: Text(friendProfile.displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      selected: service.friendIds.contains(friendProfile.id),
                      onSelected: (_) => _toggleFriend(
                        service,
                        friendProfile.id,
                        friendProfile.displayName,
                      ),
                      selectedColor: const Color(0xFFD3E4F6),
                      backgroundColor: AppColors.card,
                      avatar: const Icon(Icons.favorite_rounded, size: 15, color: Color(0xFFE26D7A)),
                      side: const BorderSide(color: AppColors.cardLine),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                ],
              ),
            const SizedBox(height: 22),
            _InstallActions(
              rendering: service.rendering,
              pinSupported: _pinSupported,
              onPin: () => _pinWidget(context),
              onRefresh: () => service.refresh(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.widgets_rounded, size: 20, color: AppColors.inkSoft),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Compara tu burbuja de hoy con las de hasta 2 amigos en el escritorio, en horizontal o vertical. '
              'Se actualiza solo cuando cambie tu estado.',
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFriendsHint extends StatelessWidget {
  const _NoFriendsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: const Row(
        children: [
          Icon(Icons.group_off_rounded, size: 18, color: AppColors.inkSoft),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún no tienes amigos. Agrega uno con su código de amigo en el menú de la píldora '
              'flotante y vuelve para configurar la comparación.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallActions extends StatelessWidget {
  final bool rendering;
  final bool? pinSupported;
  final VoidCallback onPin;
  final VoidCallback onRefresh;

  const _InstallActions({
    required this.rendering,
    required this.pinSupported,
    required this.onPin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: FilledButton.icon(
            onPressed: rendering ? null : onPin,
            icon: rendering
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.download_for_offline_rounded, size: 19),
            label: Text(rendering ? 'Preparando…' : 'Instalar widget'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2B6FB3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ),
        if (pinSupported == false) ...[
          const SizedBox(height: 8),
          const Text(
            'Tu dispositivo no admite instalarlo desde la app: mantené presionado el escritorio y '
            'agregá el widget "Tu día" desde la lista de widgets.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: rendering ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 17, color: AppColors.ink),
          label: const Text('Actualizar burbujas',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.card,
            side: const BorderSide(color: AppColors.cardLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          ),
        ),
      ],
    );
  }
}