import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import '../features/widget_comparison/widget_cache_store.dart';
import '../services/network_timeout.dart';

/// Estado de autenticación de la app.
enum AuthStatus {
  /// Detectar la sesión existente (una sola ventana al arrancar).
  resolving,
  signedOut,
  signedIn,
}

/// Autenticación de Fase 2: **usuario + contraseña**.
///
/// El usuario jamás ve un email. Los íconos de Supabase definen
/// `<username>@tu-dia.local` como el email determinista: como los
/// usernames son únicos, el email también lo es. El perfil (id, username,
/// código de amigo) se crea solo vía el trigger `handle_new_user`.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _auth.onAuthStateChange.listen(_onAuthStateChange);
    // Estado inicial sin esperar al stream: si ya hay sesión, entramos
    // con un breve "resolviendo" mientras llega el perfil.
    final hasSession = _auth.currentSession != null;
    _status = hasSession ? AuthStatus.resolving : AuthStatus.signedOut;
    if (hasSession) {
      // Copia la sesión a prefs planas para las tareas de fondo del widget
      // (WorkManager): en ese aislado no hay `FlutterSecureStorage`, y el
      // refresh_token permite renovar el access token sin credenciales.
      unawaited(_persistSessionSnapshot());
      unawaited(_loadProfile()
          .then((_) => _setStatus(AuthStatus.signedIn))
          .catchError((Object _) {
        // Sin red (o timeout) no podemos validar la sesión persistida con el
        // servidor, pero SÍ hay una sesión guardada localmente: no
        // deslogueamos al usuario. Entramos igual y los providers de datos
        // muestran su propio error con reintento. La validación real ocurre
        // en el siguiente arranque o cuando los datos se retran con éxito.
        _profile = null;
        _setStatus(AuthStatus.signedIn);
      }));
    }
  }

  final _auth = Supabase.instance.client.auth;

  AuthStatus _status = AuthStatus.resolving;
  Profile? _profile;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Perfil del usuario conectado (propio). Nulo si no hay sesión o aún
  /// cargando.
  Profile? get profile => _profile;

  Future<void> _onAuthStateChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        unawaited(_persistSessionSnapshot());
        try {
          await _loadProfile();
        } catch (_) {
          // Sin red: entramos igual y los providers de datos mostrarán
          // su propio error con reintento.
          _profile = null;
        }
        _setStatus(AuthStatus.signedIn);
      case AuthChangeEvent.tokenRefreshed:
        // Supabase renovó el access token: refrescamos el snapshot de fondo.
        unawaited(_persistSessionSnapshot());
      case AuthChangeEvent.signedOut:
        unawaited(_clearSessionSnapshot());
        _profile = null;
        _setStatus(AuthStatus.signedOut);
      default:
        break;
    }
  }

  /// Guarda el snapshot de sesión (access token + refresh token) en prefs
  /// planas para las tareas de fondo del widget. Nota: queda en el propio
  /// dispositivo, solo legible por la app.
  Future<void> _persistSessionSnapshot() async {
    final session = _auth.currentSession;
    if (session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kAuthSessionSnapshotKey,
      jsonEncode({
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        // `expiresAt` es un timestamp Unix (segundos), no un DateTime.
        'expiresAt': session.expiresAt,
      }),
    );
  }

  Future<void> _clearSessionSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAuthSessionSnapshotKey);
  }

  void _setStatus(AuthStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    final row = await withSupabaseTimeout(
      () => Supabase.instance.client.from('profiles').select().eq('id', uid).single(),
    );
    _profile = Profile.fromMap(row);
    notifyListeners();
  }

  /// Normaliza el username a su forma canónica (minúsculas, sin espacios).
  static String normalizeUsername(String raw) => raw.trim().toLowerCase();

  /// El email interno y determinista que usa Supabase para autenticar.
  static String emailForUsername(String username) => '$username@tu-dia.local';

  /// Valida el username canónico. Devuelve un mensaje de error o null.
  static String? validateUsername(String username) {
    if (username.length < 3) {
      return 'El usuario debe tener al menos 3 caracteres.';
    }
    if (username.length > 20) {
      return 'El usuario debe tener como máximo 20 caracteres.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Usa solo letras minúsculas, números y guión bajo (_).';
    }
    return null;
  }

  /// Crea la cuenta. Requiere "Confirm email" DESACTIVADO en Supabase Auth,
  /// así el `signUp` devuelve la sesión ya iniciada. Devuelve null si todo
  /// salió bien, o un mensaje de error traducible a la UI.
  Future<String?> signUp({required String username, required String password}) async {
    final usernameKey = normalizeUsername(username);
    final usernameError = validateUsername(usernameKey);
    if (usernameError != null) return usernameError;
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    try {
      final response = await withSupabaseTimeout(
        () => _auth.signUp(
          email: emailForUsername(usernameKey),
          password: password,
          data: {'username': usernameKey},
        ),
      );
      if (response.user == null || response.session == null) {
        return 'No se pudo iniciar sesión automáticamente. Asegúrate de que "Confirm email" esté '
            'desactivado en Supabase (Authentication → Sign In / Providers → Email).';
      }
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Inicia sesión con usuario + contraseña. Devuelve null o un mensaje de
  /// error.
  Future<String?> signIn({required String username, required String password}) async {
    final usernameKey = normalizeUsername(username);
    if (usernameKey.isEmpty) return 'Escribe tu usuario.';
    try {
      await withSupabaseTimeout(
        () => _auth.signInWithPassword(
          email: emailForUsername(usernameKey),
          password: password,
        ),
      );
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Cierra la sesión. La app vuelve al login vía `onAuthStateChange`.
  Future<void> signOut() async {
    await _auth.signOut();
    // el evento signedOut también lo limpia, pero por si el stream no
    // llegara (cierre forzado), removemos el snapshot acá.
    unawaited(_clearSessionSnapshot());
  }

  static const _networkError =
      'No se pudo conectar al servidor. Verifica tu conexión e inténtalo de nuevo.';

  String _mapAuthError(AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == 'user_already_exists' || message.contains('registered')) {
      return 'Ese usuario ya existe. Prueba con otro nombre.';
    }
    if (code == 'weak_password' || message.contains('weak password') || message.contains('should be at least')) {
      return 'La contraseña es muy corta (mínimo 6 caracteres).';
    }
    if (code == 'invalid_credentials' || message.contains('invalid login credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }
    if (message.contains('user not found')) {
      return 'Ese usuario no existe.';
    }
    return _networkError;
  }
}