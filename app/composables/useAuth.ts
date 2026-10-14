import type { Session } from '@supabase/supabase-js'

export interface AppUser {
  id: string
  email: string
}

const CACHE_KEY = 'pcs:user'

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
const ready = ref(false)
let initPromise: Promise<void> | null = null

function fromSession(session: Session | null): AppUser | null {
  if (!session?.user) return null
  return { id: session.user.id, email: session.user.email ?? '' }
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

      supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT') {
          user.value = null
          writeCachedUser(null)
          return
        }
        const u = fromSession(session)
        if (u) {
          user.value = u
          writeCachedUser(u)
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

  async function signUp(email: string, password: string, displayName: string) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { display_name: displayName },
        emailRedirectTo: `${location.origin}/connexion`
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
      writeCachedUser(null)
    }
  }

  return { user, ready, init, signIn, signUp, signOut, resetPassword, updatePassword }
}
