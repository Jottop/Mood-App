import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/day_bubble_data.dart';
import '../../data/friend_data_loader.dart';
import '../../data/models/profile.dart';
import '../../data/mood_view_data.dart';
import '../../state/friends_provider.dart';
import '../../state/mood_catalog_provider.dart';
import '../home/widgets/day_entry_list.dart';
import '../home/widgets/mood_bubble.dart';
import '../history/calendar_screen.dart';
import '../history/mood_summary.dart';
import 'friend_moods_copy_sheet.dart';

/// Perfil de un amigo (solo lectura): el resumen de HOY del amigo — burbuja
/// grande con los colores de sus registros, desglose de porcentajes — y
/// acceso a su calendario read-only para repasar cualquier día.
class FriendProfileScreen extends StatefulWidget {
  final Profile friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  bool _loading = true;
  String? _error;
  FriendMoodViewData? _view;

  String get _displayName => widget.friend.displayName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final view = await fetchFriendMoodViewData(widget.friend.id);
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      // En un refresco silencioso con datos ya cargados no se rompe la
      // pantalla: se conserva lo mostrado y solo se avisa con un snackbar.
      if (silent && _view != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar. Revisa tu conexión.')),
        );
        return;
      }
      setState(() {
        _error = 'No se pudo cargar la información de $_displayName. Revisa la conexión e inténtalo de nuevo.';
        _loading = false;
      });
    }
  }

  /// Abre el panel para copiar las emociones del amigo en el catálogo
  /// propio: selección de atributos (color/emoji/nombre) y de emociones,
  /// y luego el flujo que pregunta en cuál emoción propia guardar cada copia.
  Future<void> _openCopyEmotions() async {
    final view = _view;
    if (view == null) return;
    final selection = await showFriendMoodsCopySheet(
      context,
      view: view,
      friendName: _displayName,
    );
    if (selection == null || !mounted) return;
    final applied = await runFriendCopyFlow(
      context,
      selection: selection,
      catalog: context.read<MoodCatalogProvider>(),
    );
    if (!mounted) return;
    if (applied > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied == 1
                ? 'Se actualizó 1 de tus emociones desde el perfil de $_displayName.'
                : 'Se actualizaron $applied de tus emociones desde el perfil de $_displayName.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // Al salir del perfil (back, flecha del AppBar o "volver al inicio")
        // la píldora vuelve a remarcar mi icono (selección = null => Home).
        if (didPop) {
          context.read<FriendsProvider>().selectProfile(null);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBottom,
        appBar: AppBar(
          backgroundColor: AppColors.bgBottom,
          elevation: 0,
          title: Text(_displayName,
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
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
          child: SafeArea(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.inkSoft));
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.inkSoft),
              const SizedBox(height: 14),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.ink),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.cardLine),
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final view = _view!;
    final today = DateTime.now();
    final todayAsc = view.entriesForDateAsc(today);
    final todayDesc = view.entriesForDateDesc(today);
    final bubbleLabel = todayAsc.isEmpty
        ? '$_displayName aún no registró cómo se siente hoy'
        : '$_displayName ahora se siente ${view.byId(todayAsc.last.moodId).label.toLowerCase()}';

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: AppColors.ink,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 80),
        children: [
        const Center(
          child: Text(
            'El resumen de hoy',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(height: 12),
        // Misma disposición que la burbuja del Home (flotación + auras),
        // pero con los datos del amigo: el bloque ocupa todo el ancho y la
        // esfera queda centrada, así el avatar amarra a la esquina superior
        // derecha de la pantalla, igual que en la burbuja propia, sin
        // pegarse a la esfera.
        Stack(
          alignment: Alignment.topRight,
          children: [
            SizedBox(
              width: double.infinity,
              child: Center(
                child: FloatingSphere(
                  colors: dayBubbleData(view, today).colorsTopToBottom,
                  auraColors: dayBubbleData(view, today).auraColors,
                  size: 200,
                  floatAmplitude: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: FramedAvatar(
                size: 64,
                background: widget.friend.pillBg,
                foreground: widget.friend.pillFg,
                avatar: widget.friend.avatar,
                initial: widget.friend.displayInitial,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          bubbleLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
        ),
        if (todayAsc.isNotEmpty) ...[
          const SizedBox(height: 18),
          MoodSummary(entriesAsc: todayAsc, view: view),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Hoy',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CalendarScreen(
                              view: view,
                              readOnly: true,
                              title: 'Calendario de $_displayName',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.inkSoft),
                        label: const Text('Ver su historial',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.cardLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openCopyEmotions,
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 15, color: AppColors.inkSoft),
                        label: const Text('Ver sus emociones',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.cardLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                    ],
                  ),
                  if (todayDesc.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${todayDesc.length} registro${todayDesc.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        DayEntryList(
          entriesDesc: todayDesc,
          date: today,
          view: view,
          readOnly: true,
          emptyMessage: 'Aún no registró emociones hoy.',
        ),
        ],
      ),
    );
  }
}