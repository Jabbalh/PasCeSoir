import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import 'auth_layout.dart';

/// Choix d'un nouveau mot de passe, après le lien « mot de passe oublié »
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await auth.updatePassword(_password.text);
      if (!mounted) return;
      showToast(context, 'Mot de passe modifié');
      context.go('/');
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = auth.user != null;
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nouveau mot de passe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (!connected) ...[
              const Text('Ouvrez cette page depuis le lien reçu par email.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '6 caractères minimum'),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => v == null || v.length < 6 ? '6 caractères minimum' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading || !connected ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
