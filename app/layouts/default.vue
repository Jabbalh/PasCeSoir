<script setup lang="ts">
import type { DropdownMenuItem } from '@nuxt/ui'

const route = useRoute()
const { user, isAdmin, signOut } = useAuth()
const { pendingCount } = useSync()
const toast = useToast()

const journalId = computed(() => (route.params.id as string | undefined) ?? null)

const navItems = computed(() => {
  if (!journalId.value) return []
  const base = `/journal/${journalId.value}`
  return [
    { label: 'Réveils', icon: 'i-lucide-moon-star', to: base, exact: true },
    { label: 'Démarches', icon: 'i-lucide-list-checks', to: `${base}/demarches` },
    { label: 'Stats', icon: 'i-lucide-chart-column', to: `${base}/stats` },
    { label: 'Réglages', icon: 'i-lucide-settings', to: `${base}/reglages` }
  ]
})

function isActive(item: { to: string, exact?: boolean }) {
  return item.exact ? route.path === item.to : route.path.startsWith(item.to)
}

async function logout() {
  if (pendingCount.value > 0 && !confirm(`${pendingCount.value} modification(s) n'ont pas encore été synchronisées. Se déconnecter quand même ?`)) return
  await signOut()
  toast.add({ title: 'Déconnecté', icon: 'i-lucide-log-out' })
  await navigateTo('/connexion')
}

const userMenu = computed<DropdownMenuItem[][]>(() => [
  [{ label: user.value?.email ?? '', type: 'label' }],
  [
    { label: 'Mes journaux', icon: 'i-lucide-book-heart', to: '/' },
    { label: 'Mon profil', icon: 'i-lucide-user', to: '/profil' },
    ...(isAdmin.value ? [{ label: 'Administration', icon: 'i-lucide-shield-check', to: '/admin' }] : [])
  ],
  [{ label: 'Se déconnecter', icon: 'i-lucide-log-out', color: 'error', onSelect: logout }]
])
</script>

<template>
  <div class="min-h-dvh flex flex-col bg-default">
    <header class="print:hidden sticky top-0 z-30 bg-default/85 backdrop-blur border-b border-default pt-[env(safe-area-inset-top)]">
      <div class="max-w-lg mx-auto h-14 px-4 flex items-center gap-2">
        <NuxtLink to="/" class="flex items-center gap-2 font-bold text-lg min-w-0">
          <img src="/icon.svg" alt="" class="size-7 shrink-0">
          <span class="truncate">Pas ce soir</span>
        </NuxtLink>
        <div class="ml-auto flex items-center gap-1">
          <SyncStatus v-if="user" />
          <UDropdownMenu v-if="user" :items="userMenu" :content="{ align: 'end' }">
            <UButton icon="i-lucide-circle-user-round" color="neutral" variant="ghost" aria-label="Menu utilisateur" />
          </UDropdownMenu>
        </div>
      </div>
    </header>

    <main class="flex-1 w-full max-w-lg mx-auto px-4 py-4 print:max-w-none print:p-0" :class="navItems.length ? 'pb-28' : 'pb-8'">
      <slot />
    </main>

    <nav
      v-if="navItems.length"
      class="print:hidden fixed bottom-0 inset-x-0 z-30 bg-default/90 backdrop-blur border-t border-default pb-[env(safe-area-inset-bottom)]"
    >
      <div class="max-w-lg mx-auto grid grid-cols-4">
        <NuxtLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="flex flex-col items-center gap-0.5 py-2.5 text-xs font-medium transition-colors"
          :class="isActive(item) ? 'text-primary' : 'text-muted hover:text-default'"
        >
          <UIcon :name="item.icon" class="size-6" />
          {{ item.label }}
        </NuxtLink>
      </div>
    </nav>
  </div>
</template>
