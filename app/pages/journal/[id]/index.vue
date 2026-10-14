<script setup lang="ts">
import type { Wakeup } from '~/utils/db'

const route = useRoute()
const journalId = computed(() => route.params.id as string)
const toast = useToast()

const { journal, loading, authorName } = useJournal(journalId)
const { data: wakeups } = useWakeups(journalId)
const { addWakeup, deleteWakeup } = useJournalActions()

onMounted(() => {
  try {
    localStorage.setItem('pcs:lastJournal', journalId.value)
  } catch { /* ignore */ }
})

// Rafraîchit la « nuit en cours » régulièrement (l'app peut rester ouverte longtemps)
const now = ref(new Date())
const timer = setInterval(() => (now.value = new Date()), 60_000)
onBeforeUnmount(() => clearInterval(timer))

const currentNight = computed(() => nightKey(now.value))

const nights = computed(() => {
  const groups = new Map<string, Wakeup[]>()
  for (const w of wakeups.value) {
    const key = nightKey(w.woke_at)
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key)!.push(w)
  }
  // ordre chronologique à l'intérieur d'une nuit
  for (const list of groups.values()) list.reverse()
  return groups
})

const tonight = computed(() => nights.value.get(currentNight.value) ?? [])
const pastNights = computed(() => [...nights.value.entries()].filter(([k]) => k !== currentNight.value))
const visibleNights = ref(7)

// --- Le gros bouton ---
const pressing = ref(false)
const cooldown = ref(false)

async function recordWakeup() {
  if (cooldown.value) return
  cooldown.value = true
  pressing.value = true
  setTimeout(() => (pressing.value = false), 400)
  setTimeout(() => (cooldown.value = false), 2000)
  try {
    navigator.vibrate?.(60)
  } catch { /* non supporté */ }

  const w = await addWakeup(journalId.value)
  toast.add({
    title: `Réveil enregistré à ${formatTime(w.woke_at)}`,
    description: 'Vous pourrez le compléter plus tard.',
    icon: 'i-lucide-check-circle',
    color: 'success',
    duration: 6000,
    actions: [
      { label: 'Compléter', color: 'neutral', variant: 'outline', onClick: () => navigateTo(`/journal/${journalId.value}/reveil/${w.id}`) },
      { label: 'Annuler', color: 'neutral', variant: 'ghost', onClick: () => deleteWakeup(w.id) }
    ]
  })
}
</script>

<template>
  <div v-if="!loading && !journal" class="py-10">
    <UEmpty
      icon="i-lucide-book-x"
      title="Journal introuvable"
      description="Il a peut-être été supprimé ou vous n'en faites plus partie."
      :actions="[{ label: 'Mes journaux', to: '/' }]"
    />
  </div>

  <div v-else class="space-y-6">
    <div class="text-center">
      <p class="text-sm text-muted">
        {{ journal?.name }}
      </p>
      <h1 class="text-xl font-bold">
        {{ journal?.child_name ? `${journal.child_name} s'est réveillé·e ?` : 'Un réveil ?' }}
      </h1>
    </div>

    <!-- Bouton principal -->
    <div class="flex justify-center py-2">
      <button
        type="button"
        class="relative size-56 rounded-full select-none touch-manipulation
               bg-gradient-to-br from-primary-400 to-primary-700 text-white
               shadow-[0_0_60px_-10px_var(--ui-primary)]
               flex flex-col items-center justify-center gap-2
               transition-transform duration-150 active:scale-95 disabled:opacity-80"
        :class="{ 'scale-95': pressing }"
        :disabled="cooldown"
        aria-label="Enregistrer un réveil maintenant"
        @click="recordWakeup"
      >
        <span class="absolute inset-0 rounded-full ring-4 ring-primary/30" :class="{ 'animate-ping': pressing }" />
        <UIcon :name="cooldown ? 'i-lucide-check' : 'i-lucide-baby'" class="size-16" />
        <span class="text-2xl font-extrabold tracking-wide">{{ cooldown ? 'Noté !' : 'RÉVEIL' }}</span>
        <span class="text-sm opacity-80 tabular-nums">{{ formatTime(now) }}</span>
      </button>
    </div>

    <div class="text-center">
      <UButton
        :to="`/journal/${journalId}/reveil/nouveau`"
        variant="link"
        color="neutral"
        icon="i-lucide-clock"
      >
        Saisir un réveil à une autre heure
      </UButton>
    </div>

    <!-- Nuit en cours -->
    <section class="space-y-2">
      <div class="flex items-baseline justify-between">
        <h2 class="font-semibold">
          Cette nuit
        </h2>
        <span class="text-sm text-muted">{{ tonight.length }} réveil(s)</span>
      </div>
      <div v-if="tonight.length" class="space-y-2">
        <WakeupCard v-for="w in tonight" :key="w.id" :wakeup="w" :author="authorName(w.created_by)" />
      </div>
      <p v-else class="text-sm text-muted text-center py-4 rounded-xl border border-dashed border-default">
        Aucun réveil pour l'instant. Bonne nuit ! 🌙
      </p>
    </section>

    <!-- Historique -->
    <section v-if="pastNights.length" class="space-y-4">
      <h2 class="font-semibold">
        Nuits précédentes
      </h2>
      <div v-for="[key, list] in pastNights.slice(0, visibleNights)" :key="key" class="space-y-2">
        <div class="flex items-baseline justify-between text-sm">
          <span class="text-muted capitalize">{{ nightLabel(key) }}</span>
          <UBadge color="neutral" variant="subtle" size="sm">
            {{ list.length }}
          </UBadge>
        </div>
        <WakeupCard v-for="w in list" :key="w.id" :wakeup="w" :author="authorName(w.created_by)" />
      </div>
      <UButton
        v-if="pastNights.length > visibleNights"
        block
        color="neutral"
        variant="soft"
        @click="visibleNights += 7"
      >
        Voir plus de nuits
      </UButton>
    </section>
  </div>
</template>
