import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/in_app_update_flow.dart';
import '../../core/widgets/mood_limit_dialog.dart';
import '../../data/app_update.dart';
import '../../services/date_service.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';
import '../../state/mood_catalog_provider.dart';
import '../../state/mood_provider.dart';
import '../history/calendar_screen.dart';
import '../moods/manage_moods_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/settings_screen.dart';
import 'widgets/day_entry_list.dart';
import 'widgets/mood_bubble.dart';
import 'widgets/mood_picker_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Clave de prefs para recordar el día del último chequeo automático.
  static const _lastCheckKey = 'last_update_check';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckForUpdates());
  }

  /// Chequeo silencioso de actualizaciones: una vez por DÍA, sin interrumpir
  /// (snackbar con acción "Descargar" si hay versión nueva, nada si no).
  Future<void> _autoCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    if (prefs.getString(_lastCheckKey) == today) return;
    await prefs.setString(_lastCheckKey, today);

    final update = await const AppUpdateService().fetchLatest();
    if (!mounted || update == null) return;
    final installed = await AppUpdateService.installedVersionCode();
    if (!mounted || update.versionCode <= installed) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Nueva versión v${update.versionName} disponible'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Descargar',
          onPressed: () => runInAppUpdate(context, update),
        ),
      ),
    );
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Recarga la app al deslizar hacia abajo (pull-to-refresh): primero sube
  /// lo pendiente del debounce y luego re-lee registros, catálogo, amigos y
  /// mi perfil desde la nube.
  Future<void> _refresh() async {
    final mood = context.read<MoodProvider>();
    final catalog = context.read<MoodCatalogProvider>();
    final friends = context.read<FriendsProvider>();
    final auth = context.read<AuthProvider>();
    await mood.flushNow();
    await catalog.flushNow();
    await Future.wait([
      mood.refresh(),
      catalog.refresh(),
      friends.refresh(),
      auth.refreshProfile(),
    ]);
  }

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

              // Fallo de red en la carga inicial (Fase 2): pantalla de
              // error con reintento en lugar de arrancar vacío.
              final error = provider.loadError ?? catalog.loadError;
              if (error != null) {
                return _LoadRetryView(
                  message: error,
                  onRetry: () {
                    context.read<MoodProvider>().retryLoad();
                    context.read<MoodCatalogProvider>().retryLoad();
                  },
                );
              }

              final todaysAsc = provider.todaysEntriesAsc;
              final todaysDesc = provider.todaysEntriesDesc;
              final todaysColors = todaysAsc
                  .map((e) => catalog.byId(e.moodId).color)
                  .toList();
              final todaysSpecial = todaysAsc
                  .where((e) => catalog.byId(e.moodId).isSpecial)
                  .map((e) => catalog.byId(e.moodId).color)
                  .toList();
              // Cuántas veces está registrada cada emoción hoy, para el
              // contador de la grilla de selección.
              final todaysCounts = <String, int>{};
              for (final e in todaysAsc) {
                todaysCounts[e.moodId] = (todaysCounts[e.moodId] ?? 0) + 1;
              }
              final bubbleLabel = todaysAsc.isEmpty
                  ? 'Aún no registras cómo te sientes hoy'
                  : 'Ahora te sientes ${catalog.byId(todaysAsc.last.moodId).label.toLowerCase()}';

              // Mi perfil para el avatar de la esquina de la burbuja.
              final myProfile = context.watch<AuthProvider>().profile;

              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.ink,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 80),
                  children: [
                    const _Header(),
                    const SizedBox(height: 20),
                    // La burbuja con mi avatar en la esquina superior
                    // derecha de su bloque (sin pegarse a la esfera); el
                    // toque abre la edición de mi perfil. La burbuja va en
                    // un SizedBox a ancho completo para que la columna siga
                    // centrada (dentro del Stack con alignment topRight la
                    // columna tomaba su ancho natural y se corría a la
                    // derecha).
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: MoodBubble(
                            todayColors: todaysColors,
                            label: bubbleLabel,
                            specialColors: todaysSpecial,
                          ),
                        ),
                        if (myProfile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            child: FramedAvatar(
                              size: 64,
                              background: myProfile.pillBg,
                              foreground: myProfile.pillFg,
                              avatar: myProfile.avatar,
                              initial: myProfile.displayInitial,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              ),
                              tooltip: 'Editar mi perfil',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  const _PromptCard(),
                  const SizedBox(height: 22),
                  // Fila sobre la grilla: acceso a la gestión de estados (ahora todo el
                  // título es el botón), el historial (calendario) y el
                  // reinicio del día, todo al mismo nivel.
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ManageMoodsScreen()),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.inkSoft),
                          label: const Text(
                            'Mis estados de ánimo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.card,
                            side: const BorderSide(color: AppColors.cardLine),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CalendarScreen()),
                              ),
                              tooltip: 'Historial',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.calendar_today_rounded, size: 22, color: AppColors.inkSoft),
                            ),
                            if (todaysDesc.isNotEmpty)
                              IconButton(
                                onPressed: () => _confirmResetToday(context, provider),
                                tooltip: 'Reiniciar hoy',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: const Icon(Icons.restart_alt_rounded, size: 22, color: AppColors.inkSoft),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  MoodPickerGrid(
                    moods: catalog.moods,
                    moodsCount: todaysCounts,
                    onSelect: (moodId) => _selectMood(context, provider, moodId),
                  ),
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
                        if (todaysDesc.isNotEmpty)
                          Text(
                            '${todaysDesc.length} registro${todaysDesc.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                          ),
                      ],
                    ),
                  ),
                  DayEntryList(
                    entriesDesc: todaysDesc,
                    date: DateTime.now(),
                    emptyMessage: 'Toca un estado de ánimo arriba para registrar el primero de hoy.',
                  ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
        // Ajustes (perfil, widget, actualizaciones y cierre de sesión).
        // El hub de amigos vive en la píldora flotante del fondo (Fase 2).
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            ),
          ),
          tooltip: 'Ajustes',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.settings_rounded, size: 22, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// Error de carga inicial con botón de reintento (Fase 2).
class _LoadRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.inkSoft),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
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
}

Future<void> _selectMood(BuildContext context, MoodProvider provider, String moodId) async {
  if (provider.todaysEntriesAsc.length >= MoodProvider.maxOptimalEntries) {
    final proceed = await showMoodLimitDialog(context);
    if (!proceed) return;
  }
  provider.addEntry(moodId);
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
