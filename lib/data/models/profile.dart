/// Perfil público de un usuario. Su id es el de `auth.users` (Supabase) y
/// lo que ven los amigos son [username], [friendCode] y [createdAt].
class Profile {
  final String id;
  final String username;
  final String friendCode;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.friendCode,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        friendCode: map['friend_code'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  /// Nombre para mostrar: sin "@" y con la primera letra en mayúscula. El
  /// username se guarda en minúsculas (normalizado al registrarse); esta
  /// forma es la que se muestra en la UI.
  String get displayName =>
      username.isEmpty ? username : username[0].toUpperCase() + username.substring(1);
}