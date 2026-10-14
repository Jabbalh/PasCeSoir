const MESSAGES: Record<string, string> = {
  'Invalid login credentials': 'Email ou mot de passe incorrect',
  'Email not confirmed': 'Veuillez confirmer votre email (lien reçu par email)',
  'User already registered': 'Un compte existe déjà avec cet email',
  // levée par le contrôle d'inscription côté base (message générique de Supabase Auth)
  'Database error saving new user': 'Inscription sur invitation uniquement : utilisez le lien d’invitation reçu (il a peut-être expiré ou déjà servi)',
  'Inscription sur invitation uniquement': 'Inscription sur invitation uniquement : utilisez le lien d’invitation reçu (il a peut-être expiré ou déjà servi)',
  'Failed to fetch': 'Connexion internet indisponible'
}

export function errorMessage(e: unknown): string {
  const msg = e instanceof Error
    ? e.message
    : typeof e === 'object' && e && 'message' in e
      ? String((e as { message: unknown }).message)
      : String(e)
  for (const [k, v] of Object.entries(MESSAGES)) if (msg.includes(k)) return v
  return msg
}
