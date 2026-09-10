/// Pack curado de emojis para los estados de ánimo.
///
/// Sustituye al teclado libre del teléfono (que permitía guardar cualquier
/// emoji, incluidos los que teléfonos viejos no saben renderizar — tofu □□).
/// Todos los emojis de este pack existen desde hace años en todas las
/// plataformas, y además los renderiza la fuente [kEmojiFontFamily]
/// embebida en la app, así que se ven exactamente igual en cualquier
/// teléfono.
library;

import 'package:characters/characters.dart';

/// Nombre de la familia de la fuente de emojis embebida en `pubspec.yaml`.
const String kEmojiFontFamily = 'NotoEmoji';

/// Lista de fuentes de respaldo que se aplica a todo Text que renderice un
/// emoji (ver [kEmojiFontFamily]).
const List<String> kEmojiFontFallback = [kEmojiFontFamily];

/// Emoji neutro por defecto, usado cuando un emoji guardado no está en el
/// pack (o cuando el usuario aún no eligió uno).
const String kDefaultEmoji = '🙂';

/// Emoji del estado "desconocido" (catálogo eliminado). Es Emoji 1.0, se
/// renderiza en todas partes.
const String kUnknownEmoji = '❔';

class EmojiPack {
  EmojiPack._();

  /// Categorías del selector. Comentarios en español neutro; los emojis van
  /// sin el selector de variación (U+FE0F) para normalizar la búsqueda.
  static const List<({String label, List<String> emojis})> categories = [
    (label: 'Feliz', emojis: ['😀', '😁', '😃', '😄', '😆', '😅', '😂', '😊', '😋', '😎', '😍', '🥰', '😇', '🙂', '🤗', '🤩', '😜', '🤪', '😝', '🥳']),
    (label: 'Triste', emojis: ['😢', '😭', '😔', '😞', '😟', '😕', '😥', '😦', '😧', '😫', '😪', '🥺', '😿', '💧']),
    (label: 'Enojado o estresado', emojis: ['😡', '😠', '😤', '😣', '😖', '😬', '😨', '😮', '😱', '😳', '😒', '🤬', '😾', '🙄']),
    (label: 'Calmado o neutro', emojis: ['😌', '😐', '😑', '😶', '😴', '🤔', '🤐', '🫠']),
    (label: 'Cansado o enfermo', emojis: ['😷', '🤒', '🤕', '🤢', '🤧', '🤤', '😵', '💤', '🥱', '😰', '😓', '😩']),
    (label: 'Corazones y cariño', emojis: ['❤', '💔', '💕', '💖', '💘', '💙', '💚', '💛', '💜', '💞', '💝', '💋', '💓', '💗', '💌', '❣', '💟']),
    (label: 'Energía y apoyo', emojis: ['💪', '🙌', '🙏', '👍', '👏', '🤝', '✨', '🌟', '🔥', '⚡', '💯', '🎉', '🚀', '🎊', '🏆', '👑', '💃', '🕺', '🎈']),
    (label: 'Naturaleza y clima', emojis: ['☀', '⛅', '☁', '🌧', '🌈', '🌙', '❄', '🌷', '🌱', '🌻', '🌸', '🌼', '🌺', '🌊', '🍀', '⭐']),
    (label: 'Comida y bebida', emojis: ['🍕', '🍔', '🍟', '🌮', '🍩', '🍦', '🍫', '☕', '🍵', '🍺', '🧃', '🍎', '🍓', '🍉', '🍰', '🍪', '🥗', '🍜', '🍣', '🥤']),
    (label: 'Actividades y hobbies', emojis: ['⚽', '🏀', '🎮', '🎲', '🎯', '🎨', '🎸', '🎹', '🎧', '🎬', '📚', '🎭', '🧩', '🚴', '🎳', '🖼', '🎁', '🎤', '📷']),
  ];

  /// Conjunto plano de TODOS los emojis del pack (para consultas O(1)).
  static final Set<String> all = {
    for (final c in categories) ...c.emojis,
  };

  /// ¿El string (ya normalizado) pertenece al pack?
  static bool contains(String emoji) => all.contains(emoji);

  /// Normaliza un emoji guardado y lo reencuadra dentro del pack.
  ///
  /// Quita el selector de variación (U+FE0F), los secuenciadores ZWJ (U+200D)
  /// y los modificadores de tono de piel; si el primer glifo resultante está
  /// en el pack se devuelve normalizado, si no se devuelve [kDefaultEmoji].
  /// Así ningún emoji fuera del pack (escrito a mano o llegado de la nube)
  /// renderiza como caja vacía en teléfonos sin ese glifo.
  static String sanitize(String? raw) {
    if (raw == null || raw.isEmpty) return kDefaultEmoji;
    final buffer = StringBuffer();
    for (final r in raw.runes) {
      // VS16, ZWJ y tonos de piel: separan una secuencia compleja en su
      // emoji base, que es lo que realmente buscamos dentro del pack.
      if (r == 0xFE0F || r == 0x200D) continue;
      if (r >= 0x1F3FB && r <= 0x1F3FF) continue;
      buffer.writeCharCode(r);
    }
    final first = buffer.toString().characters.firstOrNull;
    if (first == null) return kDefaultEmoji;
    return all.contains(first) ? first : kDefaultEmoji;
  }
}