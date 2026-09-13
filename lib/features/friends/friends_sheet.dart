import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/profile.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';
import 'friend_profile_screen.dart';

/// Abre la hoja inferior del hub de amigos. Con [onlyList] `true` muestra
/// solo la lista (para el chip "+N"); en `false` además el código propio y
/// el formulario de agregar (para el botón "+").
Future<void> showFriendsSheet(
  GlobalKey<NavigatorState> navigator, {
  required bool onlyList,
}) {
  final navState = navigator.currentState;
  if (navState == null) return Future.value();
  return showModalBottomSheet(
    context: navState.context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FriendsSheet(onlyList: onlyList),
  );
}

/// Hoja inferior del hub de amigos: tu código para copiar y compartir,
/// agregar por código y la lista con opción de quitar.
class FriendsSheet extends StatefulWidget {
  final bool onlyList;

  const FriendsSheet({super.key, this.onlyList = false});

  @override
  State<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<FriendsSheet> {
  final _codeController = TextEditingController();
  bool _adding = false;
  String? _addError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    if (_adding) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _adding = true;
      _addError = null;
    });
    final friends = context.read<FriendsProvider>();
    final error = await friends.addFriendByCode(_codeController.text);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _addError = error;
      if (error == null) _codeController.clear();
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Amigo agregado!'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _confirmRemove(Profile friend) async {
    final friends = context.read<FriendsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar a ${friend.displayName}?'),
        content: const Text('Dejarás de compartir tus días con esta persona. Podrás volver a agregarla después con su código.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await friends.removeFriend(friend.id);
    if (mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _copyCode() async {
    final code = context.read<AuthProvider>().profile?.friendCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado. Compártelo con tu amigo.'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBottom,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Consumer<FriendsProvider>(
          builder: (context, friends, _) => ConstrainedBox(
            // Margen inferior extra para que la última fila no quede bajo la
            // píldora flotante.
            constraints: BoxConstraints(minHeight: 80, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 84),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!widget.onlyList) ...[
                  _CodeCard(onCopy: _copyCode),
                  const SizedBox(height: 14),
                  _AddFriendForm(
                    controller: _codeController,
                    submitting: _adding,
                    error: _addError,
                    onSubmit: _addFriend,
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2, top: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mis amigos',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      Text(
                        '${friends.friends.length} amigo${friends.friends.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (friends.loading && friends.friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.inkSoft)),
                  )
                else if (friends.friends.isEmpty)
                  const _EmptyFriends()
                else ...[
                  for (final friend in friends.friends) ...[
                    _FriendTile(
                      friend: friend,
                      onTap: () {
                        context.read<FriendsProvider>().selectProfile(friend.id);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: friend)),
                        );
                      },
                      onRemove: () => _confirmRemove(friend),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con tu código de amigo + botón de copiar.
class _CodeCard extends StatelessWidget {
  final VoidCallback onCopy;

  const _CodeCard({required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final myCode = context.watch<AuthProvider>().profile?.friendCode ?? '••••••';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 26, color: AppColors.creamInk),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu código de amigo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.creamInk),
                ),
                const SizedBox(height: 2),
                Text(
                  myCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copiar código',
            icon: const Icon(Icons.copy_rounded, size: 22, color: AppColors.creamInk),
          ),
        ],
      ),
    );
  }
}

/// Formulario para agregar un amigo por código.
class _AddFriendForm extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;

  const _AddFriendForm({
    required this.controller,
    required this.submitting,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agregar por código',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            enabled: !submitting,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4, color: AppColors.ink),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final filtered = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
                return TextEditingValue(
                  text: filtered,
                  selection: TextSelection.collapsed(offset: filtered.length),
                );
              }),
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4, color: AppColors.cardLine),
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
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB3261E)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Agregar amigo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un amigo con acceso a su perfil y opción de quitarlo.
class _FriendTile extends StatelessWidget {
  final Profile friend;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FriendTile({required this.friend, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final initial = friend.displayInitial;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardLine),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.ink.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Código: ${friend.friendCode}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Quitar amigo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.person_remove_rounded, size: 22, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 36, color: AppColors.inkSoft),
          SizedBox(height: 12),
          Text(
            'Todavía no tienes amigos aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          SizedBox(height: 4),
          Text(
            'Comparte tu código con otra persona o agrégala con el suyo: la amistad se crea al instante.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}