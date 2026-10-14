<script setup lang="ts">
import type { Wakeup } from '~/utils/db'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const db = useDb()

const journalId = computed(() => route.params.id as string)
const wakeupId = computed(() => route.params.wid as string)
const isNew = computed(() => wakeupId.value === 'nouveau')

const { authorName } = useJournal(journalId)
const { data: allWakeups } = useWakeups(journalId)
const { addWakeup, updateWakeup, deleteWakeup, restoreWakeup } = useJournalActions()

const original = ref<Wakeup | null>(null)
const notFound = ref(false)
const form = reactive({
  wokeAt: toLocalInput(new Date()),
  reasons: [] as string[],
  actions: [] as string[],
  comment: ''
})

// Chargement ponctuel (pas réactif) pour ne pas écraser la saisie en cours si une synchro arrive
onMounted(async () => {
  if (isNew.value) return
  const w = await db.wakeups.get(wakeupId.value)
  if (!w || w.deleted_at) {
    notFound.value = true
    return
  }
  original.value = w
  form.wokeAt = toLocalInput(w.woke_at)
  form.reasons = [...w.reasons]
  form.actions = [...w.actions]
  form.comment = w.comment
})

/** Suggestions : valeurs par défaut + celles déjà utilisées dans ce journal, les plus fréquentes d'abord */
function suggestions(defaults: string[], field: 'reasons' | 'actions') {
  const freq = new Map<string, number>()
  for (const w of allWakeups.value) for (const v of w[field]) freq.set(v, (freq.get(v) ?? 0) + 1)
  const used = [...freq.entries()].sort((a, b) => b[1] - a[1]).map(([v]) => v)
  return [...new Set([...used, ...defaults])]
}
const reasonOptions = computed(() => suggestions(DEFAULT_REASONS, 'reasons'))
const actionOptions = computed(() => suggestions(DEFAULT_ACTIONS, 'actions'))

function goBack() {
  if (window.history.state?.back) router.back()
  else navigateTo(`/journal/${journalId.value}`)
}

const saving = ref(false)
async function save() {
  const date = new Date(form.wokeAt)
  if (Number.isNaN(date.getTime())) {
    toast.add({ title: 'Date invalide', color: 'error' })
    return
  }
  saving.value = true
  try {
    const patch = {
      woke_at: date.toISOString(),
      reasons: [...form.reasons],
      actions: [...form.actions],
      comment: form.comment === '<p></p>' ? '' : form.comment
    }
    if (isNew.value) {
      const w = await addWakeup(journalId.value, date)
      await updateWakeup(w.id, patch)
    } else {
      await updateWakeup(wakeupId.value, patch)
    }
    toast.add({ title: 'Réveil enregistré', icon: 'i-lucide-check', color: 'success', duration: 2000 })
    goBack()
  } finally {
    saving.value = false
  }
}

const confirmDelete = ref(false)
async function remove() {
  const id = wakeupId.value
  await deleteWakeup(id)
  confirmDelete.value = false
  toast.add({
    title: 'Réveil supprimé',
    icon: 'i-lucide-trash-2',
    actions: [{ label: 'Annuler', color: 'neutral', variant: 'outline', onClick: () => restoreWakeup(id) }]
  })
  goBack()
}
</script>

<template>
  <div v-if="notFound" class="py-10">
    <UEmpty
      icon="i-lucide-search-x"
      title="Réveil introuvable"
      description="Il a peut-être été supprimé."
      :actions="[{ label: 'Retour au journal', to: `/journal/${journalId}` }]"
    />
  </div>

  <div v-else class="space-y-5">
    <div class="flex items-center gap-2">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" aria-label="Retour" @click="goBack" />
      <h1 class="text-xl font-bold flex-1">
        {{ isNew ? 'Nouveau réveil' : 'Détail du réveil' }}
      </h1>
      <UButton
        v-if="!isNew"
        icon="i-lucide-trash-2"
        color="error"
        variant="ghost"
        aria-label="Supprimer"
        @click="confirmDelete = true"
      />
      <UButton icon="i-lucide-check" aria-label="Enregistrer" :loading="saving" @click="save" />
    </div>

    <form class="space-y-6" @submit.prevent="save">
      <UFormField label="Date et heure du réveil" required>
        <UInput v-model="form.wokeAt" type="datetime-local" size="xl" class="w-full" required />
      </UFormField>

      <UFormField label="Raison(s) du réveil">
        <TagPicker v-model="form.reasons" :options="reasonOptions" color="warning" placeholder="Autre raison…" />
      </UFormField>

      <UFormField label="Ce qui a été fait">
        <TagPicker v-model="form.actions" :options="actionOptions" color="success" placeholder="Autre action…" />
      </UFormField>

      <UFormField label="Commentaire">
        <RichTextEditor v-model="form.comment" placeholder="Durée, humeur, détails…" />
      </UFormField>

      <p class="text-sm text-muted flex items-center gap-1.5">
        <UIcon name="i-lucide-user-pen" class="size-4" />
        <template v-if="original">
          Enregistré par <strong class="text-default">{{ authorName(original.created_by) }}</strong>
          le {{ formatDateTime(original.created_at) }}
        </template>
        <template v-else>
          Sera enregistré à votre nom
        </template>
      </p>

      <UButton type="submit" block size="xl" icon="i-lucide-save" :loading="saving">
        Enregistrer
      </UButton>
    </form>

    <UModal v-model:open="confirmDelete" title="Supprimer ce réveil ?" description="Cette action est réversible quelques secondes.">
      <template #footer>
        <div class="flex gap-2 w-full">
          <UButton color="neutral" variant="ghost" class="flex-1 justify-center" @click="confirmDelete = false">
            Annuler
          </UButton>
          <UButton color="error" class="flex-1 justify-center" @click="remove">
            Supprimer
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
