<script setup lang="ts">
import type { Wakeup, WakeType } from '~/utils/db'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const db = useDb()

const journalId = computed(() => route.params.id as string)
const wakeupId = computed(() => route.params.wid as string)
const isNew = computed(() => wakeupId.value === 'nouveau')

const { authorName } = useJournal(journalId)
const { reasons, actions, labelOf } = useOptions(journalId)
const { addWakeup, updateWakeup, deleteWakeup, restoreWakeup, addOption } = useJournalActions()

const original = ref<Wakeup | null>(null)
const notFound = ref(false)
const form = reactive({
  wokeAt: toLocalInput(new Date()),
  wakeType: null as WakeType | null,
  reasonIds: [] as string[],
  actionIds: [] as string[],
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
  form.wakeType = w.wake_type ?? null
  form.reasonIds = [...w.reason_ids]
  form.actionIds = [...w.action_ids]
  form.comment = w.comment
})

/** « Autre… » : ajoute l'option au paramétrage du journal pour pouvoir la réutiliser */
const createReason = async (label: string) => (await addOption(journalId.value, 'reason', label)).id
const createAction = async (label: string) => (await addOption(journalId.value, 'action', label)).id

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
      wake_type: form.wakeType,
      reason_ids: [...form.reasonIds],
      action_ids: [...form.actionIds],
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

      <UFormField label="Type de réveil">
        <div class="flex flex-wrap gap-2">
          <UButton
            v-for="t in WAKE_TYPES"
            :key="t.value"
            size="md"
            :color="form.wakeType === t.value ? 'primary' : 'neutral'"
            :variant="form.wakeType === t.value ? 'solid' : 'outline'"
            :icon="t.icon"
            class="rounded-full"
            @click="form.wakeType = form.wakeType === t.value ? null : t.value"
          >
            {{ t.label }}
          </UButton>
        </div>
      </UFormField>

      <UFormField label="Raison(s) du réveil">
        <template #hint>
          <ULink :to="`/journal/${journalId}/reglages#options`" class="text-xs text-muted">Gérer la liste</ULink>
        </template>
        <TagPicker
          v-model="form.reasonIds"
          :options="reasons"
          :label-of="labelOf"
          :create="createReason"
          color="warning"
          placeholder="Autre raison…"
        />
      </UFormField>

      <UFormField label="Ce qui a été fait">
        <TagPicker
          v-model="form.actionIds"
          :options="actions"
          :label-of="labelOf"
          :create="createAction"
          color="success"
          placeholder="Autre action…"
        />
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
