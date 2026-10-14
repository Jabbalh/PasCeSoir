import type { Session } from '@supabase/supabase-js'

export interface AppUser {
  id: string
  email: string
}

const CACHE_KEY = 'pcs:user'
const ADMIN_KEY = 'pcs:admin'

function readCachedUser(): AppUser | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

function writeCachedUser(user: AppUser | null) {
  try {
    if (user) localStorage.setItem(CACHE_KEY, JSON.stringify(user))
    else localStorage.removeItem(CACHE_KEY)
  } catch { /* stockage indisponible */ }
}

const user = ref<AppUser | null>(null)
/** Administrateur de l'application (affichage uniquement : les droits sont vérifiés par la base) */
const isAdmin = ref(false)
const ready = ref(false)
let initPromise: Promise<void> | null = null

function fromSession(session: Session | null): AppUser | null {
  if (!session?.user) return null
  return { id: session.user.id, email: session.user.email ?? '' }
}

function readCachedAdmin(userId: string) {
  try {
    return localStorage.getItem(ADMIN_KEY) === userId
  } catch {
    return false
  }
}

function writeCachedAdmin(userId: string | null) {
  try {
    if (userId) localStorage.setItem(ADMIN_KEY, userId)
    else localStorage.removeItem(ADMIN_KEY)
  } catch { /* stockage indisponible */ }
}

export function useSupabase() {
  return useNuxtApp().$supabase
}

/**
 * Authentification. Hors connexion, on conserve le dernier utilisateur connu :
 * l'app reste utilisable même si le jeton ne peut pas être rafraîchi.
 */
export function useAuth() {
  const supabase = useSupabase()

  /** Charge le rôle admin (hors ligne : dernière valeur connue) */
  async function loadRole(u: AppUser) {
    isAdmin.value = readCachedAdmin(u.id)
    const { data, error } = await supabase.from('app_admins').select('user_id').eq('user_id', u.id).maybeSingle()
    if (error) return
    isAdmin.value = !!data
    writeCachedAdmin(data ? u.id : null)
  }

  function init() {
    if (initPromise) return initPromise
    initPromise = (async () => {
      user.value = readCachedUser()
      try {
        const { data } = await supabase.auth.getSession()
        const u = fromSession(data.session)
        if (u) {
          user.value = u
          writeCachedUser(u)
        }
      } catch { /* hors ligne : on garde le cache */ }
      if (user.value) loadRole(user.value)

      supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT') {
          user.value = null
          isAdmin.value = false
          writeCachedUser(null)
          writeCachedAdmin(null)
          return
        }
        const u = fromSession(session)
        if (u) {
          const changed = u.id !== user.value?.id
          user.value = u
          writeCachedUser(u)
          if (changed || event === 'SIGNED_IN') loadRole(u)
        }
      })
      ready.value = true
    })()
    return initPromise
  }

  async function signIn(email: string, password: string) {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
  }

  /**
   * Inscription : réservée aux invitations (lien de partage d'un journal ou invitation
   * à l'application créée par un admin) et aux emails autorisés, contrôle fait côté serveur.
   * Le jeton d'un journal fait aussi rejoindre ce journal automatiquement.
   */
  async function signUp(email: string, password: string, displayName: string, invite: { journal?: string, app?: string } = {}) {
    const back = invite.journal ? `?redirect=${encodeURIComponent(`/rejoindre/${invite.journal}`)}` : ''
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: displayName,
          ...(invite.journal ? { invite_token: invite.journal } : {}),
          ...(invite.app ? { app_invite: invite.app } : {})
        },
        emailRedirectTo: `${location.origin}/connexion${back}`
      }
    })
    if (error) throw error
    return { needsConfirmation: !data.session }
  }

  async function resetPassword(email: string) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${location.origin}/nouveau-mot-de-passe`
    })
    if (error) throw error
  }

  async function updatePassword(password: string) {
    const { error } = await supabase.auth.updateUser({ password })
    if (error) throw error
  }

  async function signOut() {
    try {
      await supabase.auth.signOut({ scope: 'local' })
    } finally {
      user.value = null
      isAdmin.value = false
      writeCachedUser(null)
      writeCachedAdmin(null)
    }
  }

  return { user, isAdmin, ready, init, signIn, signUp, signOut, resetPassword, updatePassword }
}
