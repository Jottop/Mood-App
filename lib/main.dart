import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/local_mood_catalog_repository.dart';
import 'data/repositories/local_mood_repository.dart';
import 'features/home/home_screen.dart';
import 'state/mood_catalog_provider.dart';
import 'state/mood_provider.dart';

void main() {
  runApp(const MoodApp());
}

class MoodApp extends StatelessWidget {
  const MoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MoodProvider(repository: LocalMoodRepository())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => MoodCatalogProvider(repository: LocalMoodCatalogRepository())..load(),
        ),
      ],
      child: _LifecycleHandler(
        child: MaterialApp(
          title: 'Tu día',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const HomeScreen(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
