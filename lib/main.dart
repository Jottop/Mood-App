import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/supabase_mood_catalog_repository.dart';
import 'data/repositories/supabase_mood_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/friends/friends_hub.dart';
import 'features/home/home_screen.dart';
import 'features/widget_comparison/widget_comparison_service.dart';
import 'services/network_timeout.dart';
import 'state/auth_provider.dart';
import 'state/friends_provider.dart';
import 'state/mood_catalog_provider.dart';
import 'state/mood_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
      ).timeout(kSupabaseRequestTimeout);
    } on TimeoutException {
      // La inicialización no debe colgar el arranque con red inestable:
      // mostramos un reintento claro en vez de quedarnos en el splash para
      // siempre. `main()` se puede volver a invocar desde el botón.
      runApp(const _InitFailedScreen());
      return;
    }
  }
  runApp(const MoodApp());
}

class MoodApp extends StatelessWidget {
  const MoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin `--dart-define` (p. ej. builds sin claves) mostramos un aviso en
    // vez de romper al acceder a `Supabase.instance`.
    if (!Env.isSupabaseConfigured) {
      return MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        title: 'Tu día',
        home: const _MissingConfigScreen(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const _AppGate(),
    );
  }
}

/// Decide qué pantalla mostrar según el estado de autenticación. La sesión
/// persiste entre arranques (Supabase guarda el token), así que si ya hay
/// sesión entramos directo al shell de datos.
///
/// IMPORTANTE: los providers de datos viven POR ENCIMA del MaterialApp de
/// la sesión activa, porque las rutas empujadas (Historial, Detalle de un
/// día, gestor de estados, Amigos) son hermanas de `home` dentro del
/// Navigator y necesitan los mismos providers.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => switch (auth.status) {
        AuthStatus.resolving => const _AppFrame(home: _SplashScreen()),
        AuthStatus.signedOut => const _AppFrame(home: LoginScreen()),
        AuthStatus.signedIn => MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => MoodProvider(repository: SupabaseMoodRepository())..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => MoodCatalogProvider(repository: SupabaseMoodCatalogRepository())..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => FriendsProvider()..refresh(),
              ),
            ],
            child: const _LifecycleHandler(
              child: _AppFrame(showFriendsHub: true, home: HomeScreen()),
            ),
          ),
      },
    );
  }
}

/// Un `MaterialApp` con la configuración común de la app (tema, título).
/// Se instancia una vez por estado de auth: los providers de datos
/// acompañan arriba al de sesión activa, y se desechan al cerrarla.
/// Con [showFriendsHub] activo envuelve el Navigator con el hub flotante de
/// amigos (se ve sobre todas las rutas empujadas).
class _AppFrame extends StatefulWidget {
  final Widget home;
  final bool showFriendsHub;

  const _AppFrame({required this.home, this.showFriendsHub = false});

  @override
  State<_AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<_AppFrame> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Tu día',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: widget.home,
      builder: widget.showFriendsHub
          ? (context, child) => FriendsHubOverlay(
                navigator: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              )
          : null,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.inkSoft),
      ),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.inkSoft),
                SizedBox(height: 16),
                Text(
                  'Falta configurar Supabase',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                SizedBox(height: 8),
                Text(
                  'Compila con --dart-define=SUPABASE_PUBLISHABLE_KEY=... para iniciar la app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Se muestra si `Supabase.initialize` no terminó dentro del timeout (red
/// completamente caída). El botón vuelve a lanzar `main()`, que reintenta la
/// inicialización; si ya se completó en segundo plano, entra directo.
class _InitFailedScreen extends StatelessWidget {
  const _InitFailedScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      title: 'Tu día',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.inkSoft),
                  const SizedBox(height: 16),
                  const Text(
                    'No pudimos conectar con el servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Revisa tu conexión e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => main(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Observa el ciclo de vida de la app para forzar el guardado diferido de
/// los providers: si la app se pausa (fondo) o se destruye justo después
/// de un toque, el cambio no se pierde aunque aún no venció el debounce.
class _LifecycleHandler extends StatefulWidget {
  final Widget child;

  const _LifecycleHandler({required this.child});

  @override
  State<_LifecycleHandler> createState() => _LifecycleHandlerState();
}

class _LifecycleHandlerState extends State<_LifecycleHandler> with WidgetsBindingObserver {
  // Vive aquí (por debajo de los providers de datos) porque necesita leer
  // MoodProvider/MoodCatalogProvider para conocer mi burbuja. Se expone con
  // `Provider.value` para que la pantalla del widget y el header lo alcancen.
  late final WidgetComparisonService _widgetService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetService = WidgetComparisonService(
      moodProvider: context.read<MoodProvider>(),
      catalogProvider: context.read<MoodCatalogProvider>(),
    )..init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(context.read<MoodProvider>().flushNow());
      unawaited(context.read<MoodCatalogProvider>().flushNow());
    }
    // Al volver a la app el día puede haber cambiado (burbujas de hoy):
    // re-publicamos la escena del widget con los datos más frescos.
    if (state == AppLifecycleState.resumed) {
      unawaited(_widgetService.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    // `ChangeNotifierProvider` (no `Provider`): el servicio es un
    // ChangeNotifier y la pantalla del widget hace `watch` de él; con
    // `Provider.value` Provider avisa como error de arranque que no va a
    // notificar dependientes y descarta los rebuilds reactivos.
    // Usamos `.value` porque la propiedad es nuestra (dispose propio).
    return ChangeNotifierProvider<WidgetComparisonService>.value(
      value: _widgetService,
      child: widget.child,
    );
  }
}