import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/color_row.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/mood_view_data.dart';
import '../../state/friends_provider.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import 'mood_comparison_scene.dart';
import 'widget_bg_prefs.dart';
import 'widget_comparison_service.dart';

/// Configuración de los widgets de comparación del escritorio: elegir el
/// amigo cuya burbuja se compara con la mía, ver una preview de cada widget
/// (horizontal y vertical) y pedirle al sistema instalar cada AppWidget
/// (pin nativo, Android 8+).
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
    // Al cambiar el color de fondo del widget las previews de arriba se
    // repintan con el nuevo degradado (mismo `ValueNotifier` que escribe el
    // picker).
    widgetBgColor.addListener(_onWidgetBgChanged);
  }

  void _onWidgetBgChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widgetBgColor.removeListener(_onWidgetBgChanged);
    super.dispose();
  }

  Future<void> _pinWidget(BuildContext context, String providerName) async {
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: providerName,
    );
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      content: const Text('Elige la posición del widget en tu escritorio.'),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WidgetComparisonService>();
    final friends = context.watch<FriendsProvider>().friends;
    final moodProvider = context.read<MoodProvider>();
    final catalog = context.read<MoodCatalogProvider>();

    final localView = LocalMoodViewData(provider: moodProvider, catalog: catalog);
    final mine = dayBubbleData(localView, DateTime.now());
    final friendView = service.friendView;
    final friend = friendView == null
        ? const DayBubbleData(colorsTopToBottom: [])
        : dayBubbleData(friendView, DateTime.now());

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
              'Elige tus widgets',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            _WidgetCard(
              title: 'Widget horizontal',
              description: 'Burbujas lado a lado en un marco ancho (2×1).',
              layout: WidgetLayout.horizontal,
              mine: mine,
              friend: friend,
              mineLabel: 'Yo',
              friendLabel: service.friendName ?? '—',
              installLabel: 'Instalar widget horizontal',
              rendering: service.rendering,
              background: service.widgetBackgroundColor,
              onInstall: () => _pinWidget(
                  context, 'com.example.mood_app.MoodComparisonProvider'),
            ),
            const SizedBox(height: 16),
            _WidgetCard(
              title: 'Widget vertical',
              description: 'Burbujas apiladas en un marco alto (2×2). '
                  'Estíralo en el escritorio hasta que su alto sea el ancho '
                  'del horizontal y las burbujas se ajustan solas.',
              layout: WidgetLayout.vertical,
              mine: mine,
              friend: friend,
              mineLabel: 'Yo',
              friendLabel: service.friendName ?? '—',
              installLabel: 'Instalar widget vertical',
              rendering: service.rendering,
              background: service.widgetBackgroundColor,
              onInstall: () => _pinWidget(
                  context, 'com.example.mood_app.MoodVerticalProvider'),
            ),
            const SizedBox(height: 16),
            // Las mismas opciones que al cambiar el fondo del perfil
            // (presets suaves + color personalizado). Se guarda al tocar y
            // el widget se repinta al instante.
            ColorRow(
              label: 'Color de fondo del widget',
              current: widgetBgColor.value,
              presets: AppColors.homeBgPresets,
              onPick: (c) => saveWidgetBackgroundColor(c),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mismas opciones que en tu perfil. Se aplica al instante a los dos widgets.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
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
            if (_pinSupported == false) ...[
              const SizedBox(height: 10),
              const Text(
                'Tu dispositivo no admite instalarlo desde la app: mantené presionado el escritorio y '
                'agregá los widgets "Tu día" desde la lista de widgets.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '¿Quién comparas contigo?',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
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
                      selected: service.friendId == friendProfile.id,
                      onSelected: (_) {
                        service.selectFriend(
                          friendProfile.id,
                          displayName: friendProfile.displayName,
                        );
                      },
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
            OutlinedButton.icon(
              onPressed: service.rendering ? null : service.refresh,
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

class _WidgetCard extends StatelessWidget {
  final String title;
  final String description;
  final WidgetLayout layout;
  final DayBubbleData mine;
  final DayBubbleData friend;
  final String mineLabel;
  final String friendLabel;
  final String installLabel;
  final bool rendering;
  final Color? background;
  final VoidCallback onInstall;

  const _WidgetCard({
    required this.title,
    required this.description,
    required this.layout,
    required this.mine,
    required this.friend,
    required this.mineLabel,
    required this.friendLabel,
    required this.installLabel,
    required this.rendering,
    this.background,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          MoodComparisonScene(
            mine: mine,
            friend: friend,
            mineLabel: mineLabel,
            friendLabel: friendLabel,
            layout: layout,
            background: background,
            // La preview vertical se muestra compacta (tope de alto) para no
            // robarle todo el espacio a la tarjeta; el horizontal ocupa el
            // ancho completo.
            maxHeight: layout == WidgetLayout.vertical ? 240 : null,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: FilledButton.icon(
              onPressed: rendering ? null : onInstall,
              icon: rendering
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.download_for_offline_rounded, size: 19),
              label: Text(rendering ? 'Preparando…' : installLabel),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2B6FB3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ],
      ),
    );
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
              'Compara tu burbuja de hoy con la de un amigo directamente en el escritorio '
              'con dos widgets: uno horizontal y uno vertical. Elige un amigo, instala el '
              'que prefieras (o ambos) y se actualizará solo cuando cambies tu estado.',
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