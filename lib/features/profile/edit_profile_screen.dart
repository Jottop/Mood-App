import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/avatar.dart';
import '../../data/pill_capsule_prefs.dart';
import '../../state/auth_provider.dart';
import '../moods/widgets/custom_color_picker.dart';

const _bgPresets = <Color>[
  Color(0xFFFBF3DE), // cream
  Color(0xFFFFFFFF), // blanco
  Color(0xFFF8E1EC), // rosa pálido
  Color(0xFFD6E8F9), // celeste
  Color(0xFFE1F3E4), // verde pálido
  Color(0xFFFCEAD6), // arena
  Color(0xFFEDE4FA), // malva
  Color(0xFFFDE1C7), // durazno
];

const _fgPresets = <Color>[
  Color(0xFF7A6A3F), // creamInk
  Color(0xFF2B3A4A), // ink
  Color(0xFFFFFFFF), // blanco
  Color(0xFF5E7181), // inkSoft
  Color(0xFFB3261E), // rojo
  Color(0xFF2B6FB3), // azul
  Color(0xFF3E8E4E), // verde
  Color(0xFF7A4EA5), // violeta
];

/// Tonos suaves para el fondo del Home/perfil (el primero es el estándar).
const _homeBgPresets = <Color>[
  Color(0xFFEAF3FC), // bgTop (estándar)
  Color(0xFFFBF3DE), // cream
  Color(0xFFF8E1EC), // rosa pálido
  Color(0xFFD6E8F9), // celeste
  Color(0xFFE1F3E4), // verde pálido
  Color(0xFFFCEAD6), // arena
  Color(0xFFEDE4FA), // malva
  Color(0xFFFDE1C7), // durazno
];

/// Editor del perfil propio: alias, avatar de fruta animada y los colores de
/// tu perfil (inicial, fondo del avatar, cápsula del hub y fondo de la app).
/// El acceso (usuario y contraseña) vive en Ajustes > Usuario y contraseña.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _aliasController;

  late String? _avatar;
  late Color _pillBg;
  late Color _pillFg;
  late Color _homeBg;

  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _aliasController = TextEditingController(text: profile?.alias ?? '');
    _avatar = profile?.avatar;
    _pillBg = profile?.pillBg ?? AppColors.cream;
    _pillFg = profile?.pillFg ?? AppColors.creamInk;
    _homeBg = profile?.homeBg ?? AppColors.bgTop;
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.updateProfile(
      alias: _aliasController.text,
      avatar: _avatar,
      pillBg: _pillBg,
      pillFg: _pillFg,
      homeBg: _homeBg,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    if (error != null) {
      showAppSnackBar(context, content: Text(error));
      return;
    }
    showAppSnackBar(
      context,
      content: const Text('Perfil actualizado.'),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Editar perfil',
            style:
                TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          children: [
            const _SectionTitle('Alias'),
            const SizedBox(height: 8),
            TextField(
              controller: _aliasController,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                label: 'Alias (lo que verán tus amigos)',
                icon: Icons.badge_outlined,
                counter: 'Opcional. Si lo dejas vacío se muestra tu usuario.',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Tu avatar'),
            const SizedBox(height: 8),
            _avatarPicker(),
            const SizedBox(height: 24),

            const _SectionTitle('Colores'),
            const SizedBox(height: 4),
            const Text(
              'Colorea tu inicial, el fondo de tu avatar y la cápsula del hub. El perfil lo ven tus amigos; la cápsula solo se guarda en este dispositivo.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            _ColorRow(
                label: 'Color de la inicial',
                current: _pillFg,
                presets: _fgPresets,
                onPick: (c) => setState(() => _pillFg = c)),
            const SizedBox(height: 14),
            _ColorRow(
                label: 'Color del fondo del avatar',
                current: _pillBg,
                presets: _bgPresets,
                onPick: (c) => setState(() => _pillBg = c)),
            const SizedBox(height: 14),
            ValueListenableBuilder<Color>(
              valueListenable: pillCapsuleBg,
              builder: (context, capsuleBg, _) => _ColorRow(
                label: 'Color de la cápsula de amigos',
                current: capsuleBg,
                presets: _bgPresets,
                onPick: savePillCapsuleBg,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Se guarda al tocar, sin necesidad de pulsar «Guardar cambios».',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            _ColorRow(
                label: 'Color del fondo de perfil',
                current: _homeBg,
                presets: _homeBgPresets,
                onPick: (c) => setState(() => _homeBg = c)),
            const SizedBox(height: 24),

            const _SectionTitle('Vista previa'),
            const SizedBox(height: 8),
            Center(child: _preview()),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingProfile ? null : _saveProfile,
                icon: _savingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Guardar cambios',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _AvatarOption(
          avatar: null,
          label: 'Inicial',
          selected: _avatar == null,
          background: _pillBg,
          foreground: _pillFg,
          initial: _aliasController.text.trim().isNotEmpty
              ? _aliasController.text.trim()[0].toUpperCase()
              : _initialOfProfile(),
          onTap: () => setState(() => _avatar = null),
        ),
        for (var i = 0; i < fruitAvatarCount; i++)
          _AvatarOption(
            avatar: fruitAvatarKey(i),
            label: fruitAvatarName(i),
            selected: _avatar == fruitAvatarKey(i),
            background: _pillBg,
            foreground: _pillFg,
            initial: 'A',
            onTap: () => setState(() => _avatar = fruitAvatarKey(i)),
          ),
      ],
    );
  }

  String _initialOfProfile() {
    final profile = context.read<AuthProvider>().profile;
    return profile?.displayInitial ?? '?';
  }

  Widget _preview() {
    final alias = _aliasController.text.trim();
    final initial =
        alias.isNotEmpty ? alias[0].toUpperCase() : _initialOfProfile();
    return ValueListenableBuilder<Color>(
      valueListenable: pillCapsuleBg,
      builder: (context, capsuleBg, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient(_homeBg),
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardLine),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: capsuleBg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarBadge(
                  size: 40,
                  background: _pillBg,
                  foreground: _pillFg,
                  avatar: _avatar,
                  initial: initial,
                ),
                const SizedBox(width: 9),
                const Icon(Icons.add_rounded,
                    size: 20, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? counter,
    void Function(String)? onChanged,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      counterText: counter == null && onChanged == null ? '' : null,
      helperText: counter,
      helperStyle: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
    );
  }
}

/// Opción del selector de avatar: tile cuadrado con el avatar y su nombre.
class _AvatarOption extends StatelessWidget {
  final String? avatar;
  final String label;
  final bool selected;
  final Color background;
  final Color foreground;
  final String initial;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.avatar,
    required this.label,
    required this.selected,
    required this.background,
    required this.foreground,
    required this.initial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            AvatarBadge(
              size: 48,
              background: background,
              foreground: foreground,
              avatar: avatar,
              initial: initial,
              selected: selected,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de color con swatches preseleccionados + botón de color personalizado.
class _ColorRow extends StatelessWidget {
  final String label;
  final Color current;
  final List<Color> presets;
  final ValueChanged<Color> onPick;

  const _ColorRow({
    required this.label,
    required this.current,
    required this.presets,
    required this.onPick,
  });

  Future<void> _openCustom(BuildContext context) async {
    final color = await showCustomColorPicker(context, initialColor: current);
    if (color != null) onPick(color);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final color in presets)
              GestureDetector(
                onTap: () => onPick(color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current.toARGB32() == color.toARGB32()
                          ? AppColors.ink
                          : AppColors.cardLine,
                      width: current.toARGB32() == color.toARGB32() ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openCustom(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardLine),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 20, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
