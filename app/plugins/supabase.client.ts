import { createClient, type SupabaseClient } from '@supabase/supabase-js'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig().public
  if (!config.supabaseUrl || !config.supabaseKey) {
    console.error('[Pas ce soir] NUXT_PUBLIC_SUPABASE_URL / NUXT_PUBLIC_SUPABASE_KEY manquants')
  }
  const supabase: SupabaseClient = createClient(config.supabaseUrl, config.supabaseKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: 'pkce'
    }
  })
  return { provide: { supabase } }
})
