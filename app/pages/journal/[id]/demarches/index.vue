<script setup lang="ts">
const route = useRoute()
const journalId = computed(() => route.params.id as string)

const { journal } = useJournal(journalId)
const { data: approaches, loading } = useApproaches(journalId)

const today = ref(toDateKey(new Date()))
const timer = setInterval(() => (today.value = toDateKey(new Date())), 60_000)
onBeforeUnmount(() => clearInterval(timer))

const groups = computed(() => {
  const g = { en_cours: [] as typeof approaches.value, a_venir: [] as typeof approaches.value, terminee: [] as typeof approaches.value }
  for (const a of approaches.value) g[approachStatus(a, today.value)].push(a)
  // à venir : la plus proche d'abord ; terminées : la plus récemment terminée d'abord
  g.a_venir.reverse()
  g.terminee.sort((a, b) => b.end_date!.localeCompare(a.end_date!))
  return g
})

const sections = computed(() => [
  { key: 'en_cours', title: 'En cours', items: groups.value.en_cours },
  { key: 'a_venir', title: 'À venir', items: groups.value.a_venir },
  { key: 'terminee', title: 'Terminées', items: groups.value.terminee }
].filter(s => s.items.length))
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-end gap-2">
      <div class="flex-1 min-w-0">
        <p class="text-sm text-muted">
          {{ journal?.name }}
        </p>
        <h1 class="text-2xl font-bold">
          Démarches
        </h1>
      </div>
      <UButton :to="`/journal/${journalId}/demarches/nouveau`" icon="i-lucide-plus">
        Nouvelle
      </UButton>
    </div>

    <p class="text-sm text-muted">
      Rituels, médication… tout ce qui est mis en place pour améliorer les nuits, afin de suivre son effet sur les réveils.
    </p>

    <div v-if="loading" class="space-y-2">
      <USkeleton class="h-16 w-full" />
      <USkeleton class="h-16 w-full" />
    </div>

    <UEmpty
      v-else-if="!approaches.length"
      icon="i-lucide-list-checks"
      title="Aucune démarche"
      description="Ajoutez un rituel du coucher, un traitement, un changement d'environnement…"
      :actions="[{ label: 'Nouvelle démarche', icon: 'i-lucide-plus', to: `/journal/${journalId}/demarches/nouveau` }]"
    />

    <section v-for="s in sections" :key="s.key" class="space-y-2">
      <div class="flex items-baseline justify-between">
        <h2 class="font-semibold">
          {{ s.title }}
        </h2>
        <span class="text-sm text-muted">{{ s.items.length }}</span>
      </div>
      <ApproachCard v-for="a in s.items" :key="a.id" :approach="a" :today="today" />
    </section>
  </div>
</template>
