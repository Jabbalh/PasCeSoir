/** Jeton aléatoire URL-safe (144 bits) pour les liens d'invitation */
export function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(18))
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/** Partage natif si disponible, sinon copie dans le presse-papiers. Renvoie 'shared' | 'copied' | 'failed' */
export async function shareOrCopy(url: string, title: string, text: string): Promise<'shared' | 'copied' | 'failed'> {
  if (navigator.share) {
    try {
      await navigator.share({ title, text, url })
      return 'shared'
    } catch { /* partage annulé : on copie */ }
  }
  try {
    await navigator.clipboard.writeText(url)
    return 'copied'
  } catch {
    return 'failed'
  }
}
