<script setup lang="ts">
/**
 * Bandeaux PWA : nouvelle version disponible, installation de l'app,
 * et confirmation (une seule fois) que l'app fonctionne hors connexion.
 */
const { $pwa } = useNuxtApp()
const toast = useToast()

const updating = ref(false)

async function update() {
  updating.value = true
  // les données sont dans IndexedDB : le rechargement ne perd rien de ce qui a été enregistré
  await $pwa?.updateServiceWorker(true)
  // Secours : si la page n'était pas encore contrôlée par le service worker (première visite),
  // le rechargement automatique n'a pas lieu ; la nouvelle version est déjà active, on recharge.
  setTimeout(() => window.location.reload(), 2500)
}

watch(() => $pwa?.offlineReady, (ready) => {
  if (!ready) return
  toast.add({
    title: 'Prêt pour le hors connexion',
    description: 'L\'application fonctionne désormais même sans réseau.',
    icon: 'i-lucide-wifi-off',
    color: 'success'
  })
  $pwa?.cancelPrompt()
}, { immediate: true })
</script>

<template>
  <div class="fixed inset-x-0 bottom-24 z-40 px-4 pointer-events-none">
    <div class="max-w-lg mx-auto space-y-2">
      <!-- Nouvelle version -->
      <div
        v-if="$pwa?.needRefresh"
        class="pointer-events-auto rounded-xl border border-primary/40 bg-elevated shadow-lg p-3 flex items-center gap-3"
        role="alert"
      >
        <UIcon name="i-lucide-sparkles" class="size-6 text-primary shrink-0" />
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-sm">
            Nouvelle version disponible
          </p>
          <p class="text-xs text-muted">
            Enregistrez d'abord une saisie en cours.
          </p>
        </div>
        <UButton size="sm" color="neutral" variant="ghost" @click="$pwa?.cancelPrompt()">
          Plus tard
        </UButton>
        <UButton size="sm" :loading="updating" @click="update">
          Mettre à jour
        </UButton>
      </div>

      <!-- Installation (Android / Chrome desktop) -->
      <div
        v-else-if="$pwa?.showInstallPrompt && !$pwa?.isPWAInstalled"
        class="pointer-events-auto rounded-xl border border-default bg-elevated shadow-lg p-3 flex items-center gap-3"
      >
        <img src="/icon.svg" alt="" class="size-9 shrink-0">
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-sm">
            Installer Pas ce soir
          </p>
          <p class="text-xs text-muted">
            Accès direct depuis l'écran d'accueil, même hors ligne.
          </p>
        </div>
        <UButton size="sm" color="neutral" variant="ghost" aria-label="Ne plus proposer" icon="i-lucide-x" @click="$pwa?.cancelInstall()" />
        <UButton size="sm" @click="$pwa?.install()">
          Installer
        </UButton>
      </div>
    </div>
  </div>
</template>
