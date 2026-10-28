import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/section_card.dart';
import 'auth_layout.dart';

final _supabase = Supabase.instance.client;

enum _State { loading, valid, invalid }

/// Inscription sur invitation d'un administrateur (`/inscription/<jeton>`)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.token});

  final String token;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _state = _State.loading;
  var _loading = false;
  var _wasOnline = syncService.online;

  @override
  void initState() {
    super.initState();
    syncService.addListener(_onSync);
    _check();
  }

  void _onSync() {
    final online = syncService.online;
    if (online && !_wasOnline) _check();
    _wasOnline = online;
    setState(() {});
  }

  @override
  void dispose() {
    syncService.removeListener(_onSync);
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!syncService.online) return;
    setState(() => _state = _State.loading);
    try {
      final valid = await _supabase.rpc('app_invite_is_valid', params: {'p_token': widget.token});
      if (mounted) setState(() => _state = valid == true ? _State.valid : _State.invalid);
    } catch (_) {
      if (mounted) setState(() => _state = _State.invalid);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final needsConfirmation = await auth.signUp(_email.text.trim(), _password.text, _displayName.text.trim(),
          appInvite: widget.token);
      if (!mounted) return;
      if (needsConfirmation) {
        showToast(context, 'Compte créé', description: 'Confirmez votre email via le lien reçu, puis connectez-vous.');
        context.go('/connexion');
      } else {
        showToast(context, 'Bienvenue !', description: 'Créez maintenant le journal de votre enfant.');
        context.go('/');
      }
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _empty(IconData icon, String title, String description, {Widget? action}) => Column(
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      );

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (auth.user != null) {
      child = _empty(Icons.how_to_reg_outlined, 'Vous avez déjà un compte', 'Cette invitation sert à créer un nouveau compte.',
          action: TextButton(onPressed: () => context.go('/'), child: const Text('Mes journaux')));
    } else if (!syncService.online) {
      child = _empty(Icons.wifi_off, 'Connexion requise', 'Connectez-vous à internet pour créer votre compte.');
    } else if (_state == _State.loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_state == _State.invalid) {
      child = _empty(
        Icons.link_off,
        'Invitation invalide',
        'Ce lien a expiré, a déjà été utilisé ou a été révoqué. Demandez-en un nouveau.',
        action: TextButton(onPressed: () => context.go('/connexion'), child: const Text("J'ai déjà un compte")),
      );
    } else {
      child = Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              icon: Icons.mark_email_read_outlined,
              color: AppColors.primary,
              title: 'Vous êtes invité à utiliser Pas ce soir',
              description: 'Créez votre compte, puis le journal de votre enfant.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Votre prénom', hintText: 'ex. Maman, Papa, Julie…'),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Mot de passe', helperText: '6 caractères minimum'),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => v == null || v.length < 6 ? '6 caractères minimum' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer mon compte'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/connexion'), child: const Text("J'ai déjà un compte")),
          ],
        ),
      );
    }
    return AuthLayout(child: child);
  }
}
