import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import '../data/repositories/sync_exception.dart';
import '../services/network_timeout.dart';

/// Amigos del usuario conectado (Fase 2).
///
/// Las amistades se agregan al instante con el código de amigo. Cada
/// amistad es bidireccional (dos filas en `friendships`), así que al
/// agregar a alguien por código esa persona te ve como amigo de inmediato,
/// sin aceptación. Los perfiles (id, username, código, fecha de alta) son
/// de solo lectura para cualquiera (política RLS `profiles_select`).
class FriendsProvider extends ChangeNotifier {
  FriendsProvider();

  List<Profile> _friends = const [];
  bool _loading = false;

  List<Profile> get friends => _friends;
  bool get loading => _loading;

  String? _selectedProfileId;

  /// Id del perfil que se está viendo actualmente (nulo = Home/inicio).
  String? get selectedProfileId => _selectedProfileId;

  /// Marca el perfil seleccionado (o lo desmarca al volver al inicio).
  void selectProfile(String? profileId) {
    if (_selectedProfileId == profileId) return;
    _selectedProfileId = profileId;
    notifyListeners();
  }

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const SyncException('Sesión no iniciada.');
    }
    return uid;
  }

  /// Carga la lista de amigos (más recientes primero). No borra la lista
  /// actual si la consulta falla, para no parpadear en la UI.
  Future<void> refresh() async {
    final uid = _requireUserId();
    _loading = true;
    notifyListeners();
    try {
      _friends = await withSupabaseTimeout(() => _fetchFriends(uid));
    } catch (_) {
      // Si ya había lista cargada la conservamos; si es la primera vez, la
      // UI muestra el mensaje de reintento.
    }
    _loading = false;
    notifyListeners();
  }

  Future<List<Profile>> _fetchFriends(String uid) async {
    final rows = await _client
        .from('friendships')
        .select('friend_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final friendIds = [for (final r in rows) r['friend_id'] as String];
    if (friendIds.isEmpty) {
      return const [];
    }
    final profiles = await _client
        .from('profiles')
        .select('id, username, friend_code, alias, avatar, pill_bg, pill_fg, created_at')
        .inFilter('id', friendIds);
    final byId = {for (final p in profiles) p['id'] as String: Profile.fromMap(p)};
    // Mantiene el orden de la relación (más nuevos primero).
    return [for (final id in friendIds) if (byId[id] case final p?) p];
  }

  /// Agrega un amigo por su código de 6 caracteres. Devuelve `true` si la
  /// amistad se creó, o el mensaje de error a mostrar.
  Future<String?> addFriendByCode(String code) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length != 6) {
      return 'El código tiene 6 caracteres. Revisa que esté completo.';
    }
    try {
      final ok = await withSupabaseTimeout(
            () => _client.rpc('add_friend', params: {'code_input': normalized}),
          ) as bool? ??
          false;
      if (!ok) {
        return 'Ese código no existe o pertenece a tu propia cuenta.';
      }
      await refresh();
      return null;
    } catch (_) {
      // El RPC `add_friend` es SECURITY DEFINER y guarda con auth.uid();
      // un error de red o un timeout llega como excepción genérica.
      return 'No se pudo conectar. Verifica tu conexión e inténtalo de nuevo.';
    }
  }

  /// Quita un amigo. Devuelve un mensaje de error o null si salió bien.
  Future<String?> removeFriend(String friendId) async {
    try {
      await withSupabaseTimeout(
          () => _client.rpc('remove_friend', params: {'friend_id': friendId}));
      _friends = _friends.where((f) => f.id != friendId).toList();
      notifyListeners();
      return null;
    } catch (_) {
      return 'No se pudo quitar a ese amigo. Inténtalo de nuevo.';
    }
  }
}