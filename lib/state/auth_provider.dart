import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import '../data/session_snapshot.dart';
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
    _auth.onAuthStateChange.listen(
      _onAuthStateChange,
      onError: (Object error, StackTrace stackTrace) {
        // GoTrue ya registró estos errores (p. ej. un refresh que falló por
        // red o un timeout). Handler vacío: evita que se propaguen como
        // errores async no controlados.
      },
    );
    // Estado inicial sin esperar al stream: si ya hay sesión, entramos
    // con un breve "resolviendo" mientras llega el perfil.
    final hasSession = _auth.currentSession != null;
    if (hasSession) {
      unawaited(_startSignedIn());
    } else {
      // Sin sesión en memoria: la tarea de fondo pudo rotar los tokens con
      // la app cerrada y dejar el storage propio de Supabase con uno ya
      // consumido. El snapshot guarda el token MÁS reciente (aún válido):
      // se intenta restaurar antes de pedir el login.
      unawaited(_restoreFromSnapshot());
    }
  }

  final _auth = Supabase.instance.client.auth;

  AuthStatus _status = AuthStatus.resolving;
  Profile? _profile;

  /// true solo tras un arranque donde la sesión guardada fue rechazada por
  /// el servidor (rotada o vencida de verdad) y no se pudo recuperar. El
  /// login lo muestra una vez como aviso y lo consume.
  bool _sessionExpiredNotice = false;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Perfil del usuario conectado (propio). Nulo si no hay sesión o aún
  /// cargando.
  Profile? get profile => _profile;

  /// Aviso de "sesión vencida" pendiente de mostrar en el login.
  bool get sessionExpiredNotice => _sessionExpiredNotice;

  /// Marca el aviso de "sesión vencida" como leído.
  void consumeSessionExpiredNotice() => _sessionExpiredNotice = false;

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

  /// Arranque con sesión: primero se recupera el token más reciente del
  /// snapshot (la tarea de fondo pudo rotarlo mientras la app estaba
  /// cerrada; refrescar con uno ya consumido desloguearía), se refresca el
  /// snapshot y se carga el perfil.
  Future<void> _startSignedIn() async {
    await _restoreNewestSession();
    await _persistSessionSnapshot();
    try {
      await _loadProfile();
    } catch (_) {
      // Sin red (o timeout) no podemos validar la sesión persistida con el
      // servidor, pero SÍ hay una sesión guardada localmente: no
      // deslogueamos al usuario. Entramos igual y los providers de datos
      // muestran su propio error con reintento. La validación real ocurre
      // en el siguiente arranque o cuando los datos se retran con éxito.
      _profile = null;
    }
    // Si GoTrue borró la sesión durante el arranque (token rechazado), NO
    // entramos: la UI va al login y el aviso explica lo que pasó, en vez de
    // montar Home y mostrar "Sesión no iniciada." por toda la app.
    if (_auth.currentSession == null) {
      _sessionExpiredNotice = true;
      _setStatus(AuthStatus.signedOut);
      return;
    }
    _setStatus(AuthStatus.signedIn);
  }

  /// Sin sesión en memoria al arrancar (el storage propio de Supabase quedó
  /// con un token ya consumido por la tarea de fondo), se intenta restaurar
  /// desde el snapshot, que guarda el refresh token rotado MÁS reciente.
  /// Éxito → arranque normal. Rechazo del servidor → login con aviso de
  /// sesión vencida. Sin red → login sin aviso (no hay sesión que conservar).
  Future<void> _restoreFromSnapshot() async {
    final snapshot = await readSessionSnapshot();
    final refreshToken = snapshot?['refreshToken'] as String?;
    if (refreshToken == null || refreshToken.isEmpty) {
      _setStatus(AuthStatus.signedOut);
      return;
    }
    try {
      await withSupabaseTimeout(() => _auth.setSession(refreshToken));
    } on AuthRetryableFetchException {
      _setStatus(AuthStatus.signedOut);
      return;
    } on AuthException {
      // El servidor rechazó el token: la sesión quedó rotada o vencida de
      // verdad y no se puede recuperar sin las credenciales del usuario.
      _sessionExpiredNotice = true;
      unawaited(_clearSessionSnapshot());
      _setStatus(AuthStatus.signedOut);
      return;
    } catch (_) {
      // Sin red o timeout: no se validó nada; sin sesión en memoria solo
      // queda pedir el login (sin aviso de "vencida").
      _setStatus(AuthStatus.signedOut);
      return;
    }
    await _persistSessionSnapshot();
    try {
      await _loadProfile();
    } catch (_) {
      _profile = null;
    }
    _setStatus(AuthStatus.signedIn);
  }

  /// Si el snapshot guarda una sesión MÁS nueva que la de memoria (la tarea
  /// de fondo la rotó con la app cerrada), se adopta para no refrescar con
  /// un token ya consumido. Error de red o token inválido: se sigue con la
  /// sesión en memoria.
  Future<void> _restoreNewestSession() async {
    final snapshot = await readSessionSnapshot();
    final refreshToken = snapshot?['refreshToken'] as String?;
    final snapshotExpiresAt = snapshot?['expiresAt'] as int?;
    if (refreshToken == null || refreshToken.isEmpty) return;
    final current = _auth.currentSession;
    final currentExpiresAt = current?.expiresAt;
    if (currentExpiresAt != null &&
        snapshotExpiresAt != null &&
        snapshotExpiresAt <= currentExpiresAt) {
      return;
    }
    try {
      await _auth.setSession(refreshToken);
    } catch (_) {
      // Sin red o token inválido: se sigue con la sesión en memoria.
    }
  }

  /// Guarda el snapshot de sesión (access token + refresh token) en prefs
  /// planas para las tareas de fondo del widget. Nota: queda en el propio
  /// dispositivo, solo legible por la app.
  Future<void> _persistSessionSnapshot() =>
      persistSessionSnapshot(_auth.currentSession);

  Future<void> _clearSessionSnapshot() => clearSessionSnapshot();

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

  /// Re-lee mi perfil desde la nube (pull-to-refresh). Si falla, la UI sigue
  /// con el perfil en memoria sin mostrar error.
  Future<void> refreshProfile() async {
    try {
      await _loadProfile();
    } catch (_) {
      // Sin red: se conserva el perfil actual.
    }
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
    // Cierre manual del usuario: el aviso de "sesión vencida" es solo para
    // expulsiones automáticas del arranque, no para este cierre.
    _sessionExpiredNotice = false;
    await _auth.signOut();
    // el evento signedOut también lo limpia, pero por si el stream no
    // llegara (cierre forzado), removemos el snapshot acá.
    unawaited(_clearSessionSnapshot());
  }

  /// Actualiza la personalización del perfil que ven los amigos: alias
  /// (opcional), avatar de fruta animada y colores de la píldora. Devuelve
  /// un mensaje de error o null si salió bien.
  Future<String?> updateProfile({
    String? alias,
    String? avatar,
    Color? pillBg,
    Color? pillFg,
  }) async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return _networkError;
    final cleanAlias = alias?.trim();
    try {
      await withSupabaseTimeout(() => Supabase.instance.client
          .from('profiles')
          .update({
            'alias': cleanAlias == null || cleanAlias.isEmpty ? null : cleanAlias,
            'avatar': avatar,
            if (pillBg != null) 'pill_bg': pillBg.toARGB32(),
            if (pillFg != null) 'pill_fg': pillFg.toARGB32(),
          })
          .eq('id', uid));
      final current = _profile;
      if (current != null) {
        _profile = Profile(
          id: current.id,
          username: current.username,
          friendCode: current.friendCode,
          alias: cleanAlias == null || cleanAlias.isEmpty ? null : cleanAlias,
          avatar: avatar ?? current.avatar,
          pillBg: pillBg ?? current.pillBg,
          pillFg: pillFg ?? current.pillFg,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
      return null;
    } catch (_) {
      return _networkError;
    }
  }

  /// Cambia el username. Como el email de login es determinista
  /// (`<username>@tu-dia.local`), cambiarlo reautentica también el email
  /// interno de la cuenta. Devuelve un mensaje de error o null si salió bien.
  Future<String?> changeUsername(String username) async {
    final key = normalizeUsername(username);
    final usernameError = validateUsername(key);
    if (usernameError != null) return usernameError;
    final current = _profile;
    if (current != null && key == current.username) return null;
    try {
      await withSupabaseTimeout(() => _auth.updateUser(
            UserAttributes(
              email: emailForUsername(key),
              data: {'username': key},
            ),
          ));
      final uid = _auth.currentUser?.id;
      if (uid != null) {
        await withSupabaseTimeout(() => Supabase.instance.client
            .from('profiles')
            .update({'username': key})
            .eq('id', uid));
      }
      if (current != null) {
        _profile = Profile(
          id: current.id,
          username: key,
          friendCode: current.friendCode,
          alias: current.alias,
          avatar: current.avatar,
          pillBg: current.pillBg,
          pillFg: current.pillFg,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Cambia la contraseña de la cuenta. Devuelve un mensaje de error o null.
  Future<String?> changePassword(String password) async {
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    try {
      await withSupabaseTimeout(() => _auth.updateUser(UserAttributes(password: password)));
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return _networkError;
    }
  }

  static const _networkError =
      'No se pudo conectar al servidor. Verifica tu conexión e inténtalo de nuevo.';

  String _mapAuthError(AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == 'user_already_exists' || code == 'email_exists' || message.contains('registered')) {
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