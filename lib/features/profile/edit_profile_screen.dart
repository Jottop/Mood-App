import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/avatar.dart';
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

/// Editor del perfil propio: alias (lo que ven los amigos), avatar de fruta
/// animada, colores de la píldora, y credenciales (usuario y contraseña).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _aliasController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  late String? _avatar;
  late Color _pillBg;
  late Color _pillFg;

  bool _savingProfile = false;
  String? _usernameError;
  bool _changingUsername = false;
  String? _passwordError;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _aliasController = TextEditingController(text: profile?.alias ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController();
    _avatar = profile?.avatar;
    _pillBg = profile?.pillBg ?? AppColors.cream;
    _pillFg = profile?.pillFg ?? AppColors.creamInk;
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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

  Future<void> _changeUsername() async {
    if (_changingUsername) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final desired = _usernameController.text.trim().toLowerCase();
    if (desired == (auth.profile?.username ?? '')) {
      setState(() => _usernameError = null);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambiar tu usuario?'),
        content: Text(
          'Podrás iniciar sesión con «$desired» a partir de ahora. Tus amigos seguirán teniendo tu mismo código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _changingUsername = true;
      _usernameError = null;
    });
    final error = await auth.changeUsername(desired);
    if (!mounted) return;
    setState(() {
      _changingUsername = false;
      _usernameError = error;
    });
    if (error == null) {
      showAppSnackBar(
        context,
        content: const Text('Usuario actualizado.'),
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _changePassword() async {
    if (_changingPassword) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    setState(() {
      _changingPassword = true;
      _passwordError = null;
    });
    final error = await auth.changePassword(_passwordController.text);
    if (!mounted) return;
    setState(() {
      _changingPassword = false;
      _passwordError = error;
    });
    if (error == null) {
      _passwordController.clear();
      showAppSnackBar(
        context,
        content: const Text('Contraseña actualizada.'),
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: const Text('Editar perfil',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
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
            const _SectionTitle('Tu avatar'),
            const SizedBox(height: 8),
            _avatarPicker(),
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

            const _SectionTitle('Colores de tu píldora'),
            const SizedBox(height: 4),
            const Text(
              'Así te ven tus amigos en su píldora de amigos.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            _ColorRow(label: 'Color de fondo', current: _pillBg, presets: _bgPresets, onPick: (c) => setState(() => _pillBg = c)),
            const SizedBox(height: 14),
            _ColorRow(label: 'Color de la inicial', current: _pillFg, presets: _fgPresets, onPick: (c) => setState(() => _pillFg = c)),
            const SizedBox(height: 16),
            Center(child: _pillPreview()),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingProfile ? null : _saveProfile,
                icon: _savingProfile
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Guardar cambios', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 28),

            const _SectionTitle('Acceso'),
            const SizedBox(height: 4),
            const Text(
              'Tu usuario es con el que inicias sesión. Cambiarlo también cambia el email interno de la cuenta.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              maxLength: 20,
              decoration: _decoration(
                label: 'Usuario',
                icon: Icons.person_outline_rounded,
                suffix: TextButton(
                  onPressed: _changingUsername ? null : _changeUsername,
                  child: _changingUsername
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('Cambiar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            if (_usernameError != null) ...[
              const SizedBox(height: 6),
              Text(_usernameError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 18),

            const Text('Nueva contraseña', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            TextField(
              controller: _passwordController,
              obscureText: true,
              maxLength: 60,
              onSubmitted: (_) => _changePassword(),
              decoration: _decoration(
                label: 'Mínimo 6 caracteres',
                icon: Icons.lock_outline_rounded,
                suffix: TextButton(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('Cambiar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 6),
              Text(_passwordError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB3261E))),
            ],
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

  Widget _pillPreview() {
    final alias = _aliasController.text.trim();
    final initial = alias.isNotEmpty ? alias[0].toUpperCase() : _initialOfProfile();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarBadge(
            size: 34,
            background: _pillBg,
            foreground: _pillFg,
            avatar: _avatar,
            initial: initial,
          ),
          const SizedBox(width: 9),
          const Icon(Icons.add_rounded, size: 20, color: AppColors.inkSoft),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? counter,
    void Function(String)? onChanged,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      suffixIcon: suffix,
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
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
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
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
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
                child: const Icon(Icons.add_rounded, size: 20, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}