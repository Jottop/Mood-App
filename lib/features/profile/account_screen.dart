import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../state/auth_provider.dart';

/// Pantalla de la cuenta: cambiar el nombre de usuario (con el que se inicia
/// sesión) y la contraseña. Se abre desde Ajustes > Usuario y contraseña.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  String? _usernameError;
  bool _changingUsername = false;
  String? _passwordError;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        title: const Text('Usuario y contraseña',
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 60),
          children: [
            const Text(
              'Tu usuario es con el que inicias sesión. Cambiarlo también cambia el email interno de la cuenta.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              maxLength: 20,
              onSubmitted: (_) => _changeUsername(),
              decoration: _decoration(
                label: 'Usuario',
                icon: Icons.person_outline_rounded,
                counter: 'El código de tus amigos no cambia.',
              ),
            ),
            if (_usernameError != null) ...[
              const SizedBox(height: 6),
              Text(_usernameError!,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _changingUsername ? null : _changeUsername,
                child: _changingUsername
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink))
                    : const Text('Cambiar usuario',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(height: 28, color: AppColors.cardLine),
            const Text('Nueva contraseña',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            TextField(
              controller: _passwordController,
              obscureText: true,
              maxLength: 60,
              onSubmitted: (_) => _changePassword(),
              decoration: _decoration(
                label: 'Mínimo 6 caracteres',
                icon: Icons.lock_outline_rounded,
                counter: null,
              ),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 6),
              Text(_passwordError!,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _changingPassword ? null : _changePassword,
                child: _changingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink))
                    : const Text('Cambiar contraseña',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? counter,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      counterText: counter == null ? '' : null,
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