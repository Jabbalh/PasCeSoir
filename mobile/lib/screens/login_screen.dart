import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import 'auth_layout.dart';

enum _Mode { login, signup, reset }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.redirect});

  /// Route à ouvrir après connexion
  final String? redirect;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  var _mode = _Mode.login;
  var _loading = false;

  String get _redirectTo {
    final r = widget.redirect;
    return r != null && r.startsWith('/') ? r : '/';
  }

  /// Jeton d'invitation : seule voie d'inscription (contrôlée côté serveur)
  String? get _inviteToken => RegExp(r'^/rejoindre/([^/?#]+)').firstMatch(_redirectTo)?.group(1);
  bool get _isInvite => _inviteToken != null;

  @override
  void initState() {
    super.initState();
    // Arrivée par une invitation : on propose d'abord la création de compte
    if (_isInvite) _mode = _Mode.signup;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      switch (_mode) {
        case _Mode.login:
          await auth.signIn(email, _password.text);
          if (mounted) context.go(_redirectTo);
        case _Mode.signup:
          final needsConfirmation = await auth.signUp(email, _password.text, _displayName.text.trim(),
              journalInvite: _inviteToken);
          if (!mounted) return;
          if (needsConfirmation) {
            showToast(context, 'Compte créé', description: 'Confirmez votre email via le lien reçu, puis connectez-vous.');
            setState(() => _mode = _Mode.login);
          } else {
            context.go(_redirectTo);
          }
        case _Mode.reset:
          await auth.resetPassword(email);
          if (!mounted) return;
          showToast(context, 'Email envoyé', description: 'Suivez le lien reçu pour choisir un nouveau mot de passe.');
          setState(() => _mode = _Mode.login);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.reset => 'Mot de passe oublié',
      _ => 'Connexion',
    };
    final submitLabel = switch (_mode) {
      _Mode.login => 'Se connecter',
      _Mode.signup => 'Créer mon compte',
      _Mode.reset => 'Envoyer le lien',
    };

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isInvite) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vous êtes invité à rejoindre un journal', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('Connectez-vous ou créez un compte pour continuer.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isInvite && _mode != _Mode.reset)
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.signup, label: Text('Créer un compte')),
                  ButtonSegment(value: _Mode.login, label: Text("J'ai déjà un compte")),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              )
            else
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (_mode == _Mode.signup) ...[
              TextFormField(
                controller: _displayName,
                decoration: const InputDecoration(labelText: 'Votre prénom', hintText: 'ex. Maman, Papa, Julie…'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                validator: _required,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _required,
            ),
            if (_mode != _Mode.reset) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  helperText: _mode == _Mode.signup ? '6 caractères minimum' : null,
                ),
                obscureText: true,
                autofillHints: [_mode == _Mode.signup ? AutofillHints.newPassword : AutofillHints.password],
                validator: (v) => v == null || v.length < 6 ? '6 caractères minimum' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(submitLabel),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.login)
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.reset),
                child: const Text('Mot de passe oublié ?'),
              )
            else if (_mode == _Mode.reset)
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.login),
                child: const Text('Retour à la connexion'),
              ),
            if (!_isInvite && _mode == _Mode.login)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Pas encore de compte ? L'inscription se fait uniquement via le lien d'invitation envoyé par un membre d'un journal.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
