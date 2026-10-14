<script setup lang="ts">
import type { Journal } from '~/utils/db'

const db = useDb()
const { createJournal } = useJournalActions()
const toast = useToast()

const { data: journals, loading } = useLiveQuery(
  async () => (await db.journals.toArray()).filter(j => !j.deleted_at).sort((a, b) => a.name.localeCompare(b.name)),
  [] as Journal[]
)
const { data: counts } = useLiveQuery(async () => {
  const map: Record<string, number> = {}
  await db.wakeups.each((w) => {
    if (!w.deleted_at) map[w.journal_id] = (map[w.journal_id] ?? 0) + 1
  })
  return map
}, {} as Record<string, number>)

// Ouverture directe du dernier journal consulté au lancement de l'app
const autoOpen = useState('pcs:auto-open', () => true)
watch(loading, (l) => {
  if (l || !autoOpen.value) return
  autoOpen.value = false
  let last: string | null = null
  try {
    last = localStorage.getItem('pcs:lastJournal')
  } catch { /* ignore */ }
  const target = journals.value.find(j => j.id === last) ?? (journals.value.length === 1 ? journals.value[0] : undefined)
  if (target) navigateTo(`/journal/${target.id}`, { replace: true })
}, { immediate: true })

const open = ref(false)
const form = reactive({ name: '', child_name: '' })

async function create() {
  if (!form.child_name.trim()) return
  const journal = await createJournal({
    name: form.name.trim() || `Les nuits de ${form.child_name.trim()}`,
    child_name: form.child_name
  })
  open.value = false
  form.name = ''
  form.child_name = ''
  toast.add({ title: 'Journal créé', icon: 'i-lucide-book-heart', color: 'success' })
  await navigateTo(`/journal/${journal.id}`)
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-bold">
        Mes journaux
      </h1>
      <UButton icon="i-lucide-plus" @click="open = true">
        Nouveau
      </UButton>
    </div>

    <div v-if="loading" class="space-y-3">
      <USkeleton v-for="i in 2" :key="i" class="h-20 w-full" />
    </div>

    <UEmpty
      v-else-if="!journals.length"
      icon="i-lucide-moon-star"
      title="Aucun journal pour le moment"
      description="Créez le journal des nuits de votre enfant, puis partagez-le avec l'autre parent."
      :actions="[{ label: 'Créer un journal', icon: 'i-lucide-plus', size: 'lg', onClick: () => { open = true } }]"
    />

    <div v-else class="space-y-3">
      <NuxtLink
        v-for="j in journals"
        :key="j.id"
        :to="`/journal/${j.id}`"
        class="flex items-center gap-4 p-4 rounded-xl border border-default bg-elevated/50 hover:bg-elevated active:scale-[0.99] transition"
      >
        <div class="size-12 rounded-full bg-primary/15 text-primary flex items-center justify-center text-xl font-bold shrink-0">
          {{ (j.child_name || j.name).charAt(0).toUpperCase() }}
        </div>
        <div class="min-w-0 flex-1">
          <p class="font-semibold truncate">
            {{ j.name }}
          </p>
          <p class="text-sm text-muted">
            {{ counts[j.id] ?? 0 }} réveil(s) enregistré(s)
          </p>
        </div>
        <UIcon v-if="j._dirty" name="i-lucide-cloud-upload" class="text-warning size-4" />
        <UIcon name="i-lucide-chevron-right" class="text-muted size-5" />
      </NuxtLink>
    </div>

    <UModal v-model:open="open" title="Nouveau journal" description="Le journal des réveils de votre enfant">
      <template #body>
        <form id="create-journal" class="space-y-4" @submit.prevent="create">
          <UFormField label="Prénom de l'enfant" required>
            <UInput v-model="form.child_name" size="xl" class="w-full" autofocus required />
          </UFormField>
          <UFormField label="Nom du journal" :hint="form.child_name ? `Par défaut : Les nuits de ${form.child_name}` : 'Optionnel'">
            <UInput v-model="form.name" size="xl" class="w-full" />
          </UFormField>
        </form>
      </template>
      <template #footer>
        <div class="flex gap-2 w-full">
          <UButton color="neutral" variant="ghost" class="flex-1 justify-center" @click="open = false">
            Annuler
          </UButton>
          <UButton type="submit" form="create-journal" class="flex-1 justify-center" :disabled="!form.child_name.trim()">
            Créer
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
