import 'package:flutter/material.dart';

import '../../core/emoji_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/special_badge.dart';
import '../../data/models/mood_type.dart';
import '../../data/mood_view_data.dart';
import '../../state/mood_catalog_provider.dart';

/// Selección del panel de copia: qué emociones del amigo se copiaron y
/// cuáles de sus atributos se deben aplicar (color / emoji / nombre).
class FriendCopySelection {
  final List<MoodType> moods;
  final bool copyColor;
  final bool copyEmoji;
  final bool copyLabel;

  const FriendCopySelection({
    required this.moods,
    required this.copyColor,
    required this.copyEmoji,
    required this.copyLabel,
  });
}

/// Abre el panel con las emociones del amigo: arriba los chips para elegir
/// qué atributos copiar (color, emoji, nombre) y la lista para marcar cuáles
/// emociones. Devuelve la selección, o null si se cancela.
Future<FriendCopySelection?> showFriendMoodsCopySheet(
  BuildContext context, {
  required FriendMoodViewData view,
  required String friendName,
}) {
  return showModalBottomSheet<FriendCopySelection>(
    context: context,
    backgroundColor: AppColors.bgBottom,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _FriendMoodsCopySheet(view: view, friendName: friendName),
    ),
  );
}

class _FriendMoodsCopySheet extends StatefulWidget {
  final FriendMoodViewData view;
  final String friendName;

  const _FriendMoodsCopySheet({required this.view, required this.friendName});

  @override
  State<_FriendMoodsCopySheet> createState() => _FriendMoodsCopySheetState();
}

class _FriendMoodsCopySheetState extends State<_FriendMoodsCopySheet> {
  late final List<MoodType> _moods = widget.view.catalogMoods;

  bool _copyColor = true;
  bool _copyEmoji = true;
  bool _copyLabel = true;

  final Set<String> _selected = {};

  bool get _allParamsSelected => _copyColor && _copyEmoji && _copyLabel;

  bool get _allEmotionsSelected => _selected.length == _moods.length;

  bool get _canAccept => (_copyColor || _copyEmoji || _copyLabel) && _selected.isNotEmpty;

  void _toggleAllParams() {
    setState(() {
      if (_allParamsSelected) {
        _copyColor = false;
        _copyEmoji = false;
        _copyLabel = false;
      } else {
        _copyColor = true;
        _copyEmoji = true;
        _copyLabel = true;
      }
    });
  }

  void _toggleAllEmotions() {
    setState(() {
      if (_allEmotionsSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_moods.map((m) => m.id));
      }
    });
  }

  void _accept() {
    Navigator.of(context).pop(
      FriendCopySelection(
        moods: [
          for (final m in _moods)
            if (_selected.contains(m.id)) m,
        ],
        copyColor: _copyColor,
        copyEmoji: _copyEmoji,
        copyLabel: _copyLabel,
      ),
    );
  }

  /// Zona reservada en la base del panel para que la píldora flotante del
  /// hub de amigos (que vive POR ENCIMA del Navigator, sobre todas las
  /// rutas y hojas modales) no tape los botones de abajo. Mide ~62px
  /// (avatar 34 + paddings + margen SafeArea) y dejamos margen extra.
  static const double _pillReserveHeight = 78;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, _pillReserveHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emociones de ${widget.friendName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Marca qué atributos copiar (color, emoji o nombre), elige las emociones y luego decides si reemplazar una tuya o agregarla como nueva.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Copiar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _toggleAllParams,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.inkSoft,
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(_allParamsSelected ? 'Deseleccionar todo' : 'Seleccionar todo'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _attributeChip('Color', _copyColor, (v) => setState(() => _copyColor = v)),
                _attributeChip('Emoji', _copyEmoji, (v) => setState(() => _copyEmoji = v)),
                _attributeChip('Nombre', _copyLabel, (v) => setState(() => _copyLabel = v)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Sus emociones (${_selected.length}/${_moods.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _toggleAllEmotions,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.inkSoft,
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(_allEmotionsSelected ? 'Deseleccionar todo' : 'Seleccionar todo'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _moods.isEmpty
                  ? const Center(
                      child: Text(
                        'Este amigo no tiene emociones definidas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      itemCount: _moods.length,
                      itemBuilder: (context, index) {
                        final mood = _moods[index];
                        return _EmotionRow(
                          mood: mood,
                          selected: _selected.contains(mood.id),
                          onTap: () => setState(() {
                            if (!_selected.add(mood.id)) _selected.remove(mood.id);
                          }),
                          trailing: Checkbox(
                            value: _selected.contains(mood.id),
                            onChanged: (_) => setState(() {
                              if (!_selected.add(mood.id)) _selected.remove(mood.id);
                            }),
                            activeColor: AppColors.ink,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _canAccept ? _accept : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    child: Text(_selected.isEmpty ? 'Aceptar' : 'Aceptar (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attributeChip(String label, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: AppColors.ink,
      backgroundColor: AppColors.card,
      selectedColor: AppColors.cream,
      side: const BorderSide(color: AppColors.cardLine),
      labelStyle: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}

/// Acción elegida en el diálogo de destino para una emoción del amigo.
enum _CopyAction { abort, skip, replace, add }

class _CopyPick {
  final _CopyAction action;
  final MoodType? target;

  const _CopyPick._(this.action, [this.target]);

  const _CopyPick.abort() : this._(_CopyAction.abort);
  const _CopyPick.skip() : this._(_CopyAction.skip);
  const _CopyPick.replace(MoodType target) : this._(_CopyAction.replace, target);
  const _CopyPick.add() : this._(_CopyAction.add);
}

/// Aplica la copia de las emociones seleccionadas sobre el catálogo propio:
/// para cada emoción del amigo pregunta si agregarla como nueva o en cuál
/// de las propias guardarla (reemplazo). Devuelve cuántas emociones se
/// agregaron o actualizaron.
Future<int> runFriendCopyFlow(
  BuildContext context, {
  required FriendCopySelection selection,
  required MoodCatalogProvider catalog,
}) async {
  var applied = 0;
  for (final friendMood in selection.moods) {
    if (!context.mounted) return applied;
    final pick = await _showDestinationPicker(context, catalog, friendMood: friendMood);
    if (pick == null || pick.action == _CopyAction.abort || !context.mounted) return applied;
    if (pick.action == _CopyAction.skip) continue;
    if (pick.action == _CopyAction.add) {
      final proceed = await _confirmAddIfOverLimit(context, catalog);
      if (!proceed || !context.mounted) continue;
      // Agregar copia SIEMPRE todo (nombre, emoji, color y el indicador de
      // especial); los chips solo gobiernan el reemplazo.
      await catalog.addMood(
        label: friendMood.label,
        emoji: EmojiPack.sanitize(friendMood.emoji),
        color: friendMood.color,
        isSpecial: friendMood.isSpecial,
      );
      applied++;
      continue;
    }
    // Reemplazo: aplica solo los atributos que se marcaron, conservando el
    // id propio (los registros ya guardados no se tocan).
    final target = pick.target!;
    await catalog.updateMood(
      target.id,
      label: selection.copyLabel ? friendMood.label : null,
      emoji: selection.copyEmoji ? EmojiPack.sanitize(friendMood.emoji) : null,
      color: selection.copyColor ? friendMood.color : null,
    );
    applied++;
  }
  return applied;
}

/// Si ya se alcanzó el máximo óptimo de emociones, pide confirmación para
/// agregar una más (igual que el editor de estados). Devuelve `true` si se
/// puede agregar (sin diálogo si aún hay margen).
Future<bool> _confirmAddIfOverLimit(BuildContext context, MoodCatalogProvider catalog) async {
  if (catalog.moods.length < MoodCatalogProvider.maxOptimalMoods) return true;
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Límite alcanzado'),
      content: const Text(
        'Ya tienes 10 emociones, que es el máximo óptimo para un uso fluido del selector. ¿Deseas agregarla de todas formas?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Agregar de todas formas')),
      ],
    ),
  );
  return confirmed == true;
}

/// Diálogo por cada emoción del amigo: ofrece agregarla como nueva o
/// reemplazarla en alguna de las propias. Devuelve la acción elegida o null
/// si el diálogo se cierra sin decidir (se corta el resto del flujo).
Future<_CopyPick?> _showDestinationPicker(
  BuildContext context,
  MoodCatalogProvider catalog, {
  required MoodType friendMood,
}) {
  final own = catalog.moods;
  return showDialog<_CopyPick>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Copiar "${friendMood.emoji} ${friendMood.label}"'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agrégala como nueva o reemplaza una tuya. Al reemplazar se aplican solo los atributos que marcaste.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _AddNewTile(onTap: () => Navigator.of(context).pop(const _CopyPick.add())),
                  for (var i = 0; i < own.length; i++) ...[
                    if (i == 0) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'O reemplazar en alguna tuya',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _EmotionRow(
                      mood: own[i],
                      selected: false,
                      onTap: () => Navigator.of(context).pop(_CopyPick.replace(own[i])),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _CopyPick.abort()),
          style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
          child: const Text('Detener'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _CopyPick.skip()),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          child: const Text('Saltar'),
        ),
      ],
    ),
  );
}

/// Tile destacado del diálogo de destino: agrega la emoción del amigo como
/// nueva en mi catálogo (copiada completa, sin importar los chips).
class _AddNewTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Agregar como nueva',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de una emoción (del amigo o propia): círculo con su color, emoji,
/// nombre y opcionalmente el indicador de especial. [trailing] suele ser un
/// Checkbox (selección) o una flecha (diálogo de destino).
class _EmotionRow extends StatelessWidget {
  final MoodType mood;
  final bool selected;
  final VoidCallback onTap;
  final Widget trailing;

  const _EmotionRow({
    required this.mood,
    required this.selected,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Color.lerp(mood.color, Colors.white, 0.78)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: mood.color, shape: BoxShape.circle),
                  child: Text(
                    mood.emoji,
                    style: const TextStyle(fontSize: 20, fontFamilyFallback: kEmojiFontFallback),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          mood.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      if (mood.isSpecial) ...[
                        const SizedBox(width: 6),
                        const SpecialBadge(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}