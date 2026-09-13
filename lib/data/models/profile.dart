import 'package:flutter/material.dart';

/// Perfil público de un usuario. Su id es el de `auth.users` (Supabase) y
/// lo que ven los amigos son [username], [friendCode] y [createdAt], más la
/// personalización: [alias] (opcional), [avatar] (fruta animada o null =
/// inicial) y los colores de la píldora ([pillBg]/[pillFg]) con los que cada
/// quien ve el avatar del otro en el hub de amigos.
class Profile {
  final String id;
  final String username;
  final String friendCode;
  final String? alias;

  /// Identificador del avatar frutal: `fruit_0`..`fruit_4`. Null = inicial.
  final String? avatar;
  final Color pillBg;
  final Color pillFg;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.friendCode,
    this.alias,
    this.avatar,
    this.pillBg = const Color(0xFFFBF3DE),
    this.pillFg = const Color(0xFF7A6A3F),
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    final username = map['username'] as String;
    final alias = map['alias'] as String?;
    final cleanAlias = alias?.trim();
    return Profile(
      id: map['id'] as String,
      username: username,
      friendCode: map['friend_code'] as String,
      alias: cleanAlias == null || cleanAlias.isEmpty ? null : cleanAlias,
      avatar: map['avatar'] as String?,
      pillBg: Color((map['pill_bg'] as int?) ?? 0xFFFBF3DE),
      pillFg: Color((map['pill_fg'] as int?) ?? 0xFF7A6A3F),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Nombre para mostrar: el alias si está definido, si no el username sin
  /// "@" y con la primera letra en mayúscula.
  String get displayName {
    final clean = alias?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
    return username.isEmpty
        ? username
        : username[0].toUpperCase() + username.substring(1);
  }

  /// Inicial que se muestra en los avatares circulares (alias > username).
  String get displayInitial {
    final name = displayName;
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  /// Fruta animada del avatar, devuelta como índice 0..4, o null si el perfil
  /// no tiene avatar (se muestra la inicial).
  int? get fruitIndex {
    final match = RegExp(r'^fruit_([0-4])$').firstMatch(avatar ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }
}