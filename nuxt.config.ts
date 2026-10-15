// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2026-10-01',
  devtools: { enabled: true },

  // SPA : indispensable pour un fonctionnement hors connexion complet (PWA)
  ssr: false,

  modules: ['@nuxt/ui', '@vite-pwa/nuxt'],

  ui: {
    // tertiary : couleur dédiée au type de démarche « Soin »
    theme: { colors: ['primary', 'secondary', 'tertiary', 'success', 'info', 'warning', 'error'] }
  },

  css: ['~/assets/css/main.css'],

  // Site 100 % statique dans .output/public (sinon Nitro choisit le preset vercel-static sur Vercel)
  nitro: {
    preset: 'static'
  },

  app: {
    head: {
      htmlAttrs: { lang: 'fr' },
      title: 'Pas ce soir',
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
        { name: 'description', content: 'Journal des réveils nocturnes de votre enfant' },
        { name: 'theme-color', content: '#1e1b4b' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' }
      ],
      link: [
        { rel: 'icon', href: '/favicon.ico', sizes: '48x48' },
        { rel: 'icon', href: '/icon.svg', type: 'image/svg+xml' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon-180x180.png' }
      ]
    }
  },

  // Icônes embarquées dans le bundle : indispensable hors connexion
  icon: {
    // le scan ne couvre que les composants : icônes déclarées dans app/utils ajoutées à la main
    clientBundle: { scan: true, icons: ['lucide:sunrise', 'lucide:moon', 'lucide:repeat', 'lucide:pill', 'lucide:stethoscope', 'lucide:utensils', 'lucide:bed', 'lucide:circle-dot'], sizeLimitKb: 512 },
    provider: 'none'
  },

  colorMode: {
    preference: 'dark'
  },

  runtimeConfig: {
    public: {
      supabaseUrl: process.env.NUXT_PUBLIC_SUPABASE_URL || '',
      supabaseKey: process.env.NUXT_PUBLIC_SUPABASE_KEY || ''
    }
  },

  pwa: {
    // Nouvelle version : on demande à l'utilisateur avant de recharger (évite de perdre une saisie)
    registerType: 'prompt',
    manifest: {
      name: 'Pas ce soir — Journal des réveils',
      short_name: 'Pas ce soir',
      description: 'Journal des réveils nocturnes de votre enfant',
      lang: 'fr',
      theme_color: '#1e1b4b',
      background_color: '#0f0e24',
      display: 'standalone',
      orientation: 'portrait',
      start_url: '/',
      icons: [
        { src: 'pwa-64x64.png', sizes: '64x64', type: 'image/png' },
        { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
        { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        { src: 'maskable-icon-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
      ]
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2}'],
      // Les appels Supabase ne sont jamais mis en cache par le SW : la synchro est gérée par l'app (IndexedDB)
      navigateFallbackDenylist: [/^\/api\//]
    },
    client: {
      // bandeau d'installation maison à la place de la mini-barre native
      installPrompt: true,
      // une PWA reste ouverte longtemps : recherche de mise à jour toutes les heures
      periodicSyncForUpdates: 3600
    },
    devOptions: {
      enabled: false,
      type: 'module'
    }
  }
})
