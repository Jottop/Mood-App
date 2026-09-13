import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_provider.dart';
import '../home/widgets/mood_bubble.dart';

/// Pantalla de acceso (Fase 2): el login es con **usuario + contraseña**
/// (nunca un email). Alterna entre iniciar sesión y crear cuenta.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Si el arranque no pudo recuperar la sesión (el servidor rechazó el
    // token), mostramos un aviso breve antes de que el usuario vuelva a
    // entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.sessionExpiredNotice) {
        auth.consumeSessionExpiredNotice();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Tu sesión venció. Inicia sesión de nuevo.'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final error = _isRegister
        ? await auth.signUp(username: _usernameController.text, password: _passwordController.text)
        : await auth.signIn(username: _usernameController.text, password: _passwordController.text);
    if (mounted) {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Crear cuenta' : 'Iniciar sesión';
    final subtitle = _isRegister
        ? 'Tu usuario y contraseña. Elegí tus estados de ánimo y comparte tus días con amigos.'
        : 'Entrá con tu usuario y contraseña. Nunca necesitarás un email.';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Burbuja "vacía" flotante, como marca de la app.
                    const FloatingSphere(colors: [], auraColors: [], size: 110),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu día',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _usernameController,
                            enabled: !_submitting,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: _decoration(
                              label: 'Usuario',
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_submitting,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _submit(),
                            textInputAction: _isRegister ? TextInputAction.done : TextInputAction.go,
                            decoration: _decoration(
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.inkSoft,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB3261E)),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                    )
                                  : Text(
                                      title,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting ? null : _toggleMode,
                      child: Text(
                        _isRegister ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Créala ahora',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({required String label, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.bgTop,
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