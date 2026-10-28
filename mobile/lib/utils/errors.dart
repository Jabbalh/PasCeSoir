import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

const _messages = {
  'Invalid login credentials': 'Email ou mot de passe incorrect',
  'Email not confirmed': 'Veuillez confirmer votre email (lien reçu par email)',
  'User already registered': 'Un compte existe déjà avec cet email',
  // levée par le contrôle d'inscription côté base (message générique de Supabase Auth)
  'Database error saving new user':
      'Inscription sur invitation uniquement : utilisez le lien d’invitation reçu (il a peut-être expiré ou déjà servi)',
  'Inscription sur invitation uniquement':
      'Inscription sur invitation uniquement : utilisez le lien d’invitation reçu (il a peut-être expiré ou déjà servi)',
  'Failed host lookup': 'Connexion internet indisponible',
};

/// Traduit une erreur (Supabase, réseau…) en message affichable
String errorMessage(Object e) {
  if (e is SocketException) return 'Connexion internet indisponible';
  final msg = switch (e) {
    AuthException(:final message) => message,
    PostgrestException(:final message) => message,
    _ => e.toString(),
  };
  for (final entry in _messages.entries) {
    if (msg.contains(entry.key)) return entry.value;
  }
  return msg;
}
