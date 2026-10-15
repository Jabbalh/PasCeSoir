<script setup lang="ts">
import type { Approach, ApproachKind, DayPeriod } from '~/utils/db'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const db = useDb()

const journalId = computed(() => route.params.id as string)
const approachId = computed(() => route.params.aid as string)
const isNew = computed(() => approachId.value === 'nouveau')

const { authorName } = useJournal(journalId)
const { addApproach, updateApproach, deleteApproach, restoreApproach } = useJournalActions()

const today = toDateKey(new Date())
const original = ref<Approach | null>(null)
const notFound = ref(false)
const form = reactive({
  kind: null as ApproachKind | null,
  label: '',
  startDate: today,
  endDate: '',
  periods: [] as DayPeriod[],
  comment: ''
})

// Chargement ponctuel (pas réactif) pour ne pas écraser la saisie en cours si une synchro arrive
onMounted(async () => {
  if (isNew.value) return
  const a = await db.approaches.get(approachId.value)
  if (!a || a.deleted_at) {
    notFound.value = true
    return
  }
  original.value = a
  form.kind = a.kind
  form.label = a.label
  form.startDate = a.start_date
  form.endDate = a.end_date ?? ''
  form.periods = [...a.periods]
  form.comment = a.comment
})

function togglePeriod(p: DayPeriod) {
  form.periods = form.periods.includes(p) ? form.periods.filter(x => x !== p) : [...form.periods, p]
}

const ongoing = computed(() => !form.endDate)

function goBack() {
  if (window.history.state?.back) router.back()
  else navigateTo(`/journal/${journalId.value}/demarches`)
}

const saving = ref(false)
async function save() {
  if (!form.kind) {
    toast.add({ title: 'Choisissez un type de démarche', color: 'error' })
    return
  }
  if (!form.label.trim()) {
    toast.add({ title: 'Indiquez un nom pour la démarche', color: 'error' })
    return
  }
  if (!form.startDate) {
    toast.add({ title: 'Indiquez la date de début', color: 'error' })
    return
  }
  if (form.endDate && form.endDate < form.startDate) {
    toast.add({ title: 'La date de fin doit suivre la date de début', color: 'error' })
    return
  }
  saving.value = true
  try {
    const input = {
      kind: form.kind,
      label: form.label.trim(),
      start_date: form.startDate,
      end_date: form.endDate || null,
      // ordre de la journée, quel que soit l'ordre de sélection
      periods: DAY_PERIODS.map(p => p.value).filter(p => form.periods.includes(p)),
      comment: form.comment === '<p></p>' ? '' : form.comment
    }
    if (isNew.value) await addApproach(journalId.value, input)
    else await updateApproach(approachId.value, input)
    toast.add({ title: 'Démarche enregistrée', icon: 'i-lucide-check', color: 'success', duration: 2000 })
    goBack()
  } finally {
    saving.value = false
  }
}

const confirmDelete = ref(false)
async function remove() {
  const id = approachId.value
  await deleteApproach(id)
  confirmDelete.value = false
  toast.add({
    title: 'Démarche supprimée',
    icon: 'i-lucide-trash-2',
    actions: [{ label: 'Annuler', color: 'neutral', variant: 'outline', onClick: () => restoreApproach(id) }]
  })
  goBack()
}
</script>

<template>
  <div v-if="notFound" class="py-10">
    <UEmpty
      icon="i-lucide-search-x"
      title="Démarche introuvable"
      description="Elle a peut-être été supprimée."
      :actions="[{ label: 'Retour aux démarches', to: `/journal/${journalId}/demarches` }]"
    />
  </div>

  <div v-else class="space-y-5">
    <div class="flex items-center gap-2">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" aria-label="Retour" @click="goBack" />
      <h1 class="text-xl font-bold flex-1">
        {{ isNew ? 'Nouvelle démarche' : 'Démarche' }}
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
      <UFormField label="Type" required>
        <div class="flex flex-wrap gap-2">
          <UButton
            v-for="k in APPROACH_KINDS"
            :key="k.value"
            size="md"
            :color="form.kind === k.value ? 'primary' : 'neutral'"
            :variant="form.kind === k.value ? 'solid' : 'outline'"
            :icon="k.icon"
            class="rounded-full"
            @click="form.kind = k.value"
          >
            {{ k.label }}
          </UButton>
        </div>
      </UFormField>

      <UFormField label="Nom" required>
        <UInput v-model="form.label" size="xl" class="w-full" placeholder="Ex. Bain avant le coucher, mélatonine 1 mg…" required />
      </UFormField>

      <div class="grid grid-cols-2 gap-3">
        <UFormField label="Du" required>
          <UInput v-model="form.startDate" type="date" class="w-full" :max="form.endDate || undefined" required />
        </UFormField>
        <UFormField label="Au" :hint="ongoing ? 'En cours' : undefined">
          <UInput v-model="form.endDate" type="date" class="w-full" :min="form.startDate" />
        </UFormField>
      </div>
      <div class="-mt-3 flex flex-wrap gap-2">
        <UButton
          v-if="ongoing"
          size="sm"
          color="neutral"
          variant="soft"
          icon="i-lucide-square"
          :disabled="form.startDate > today"
          @click="form.endDate = today"
        >
          Terminer aujourd'hui
        </UButton>
        <UButton
          v-else
          size="sm"
          color="neutral"
          variant="soft"
          icon="i-lucide-play"
          @click="form.endDate = ''"
        >
          Toujours en cours (sans date de fin)
        </UButton>
      </div>

      <UFormField label="Moment(s) de la journée">
        <div class="flex flex-wrap gap-2">
          <UButton
            v-for="p in DAY_PERIODS"
            :key="p.value"
            size="md"
            :color="form.periods.includes(p.value) ? 'primary' : 'neutral'"
            :variant="form.periods.includes(p.value) ? 'solid' : 'outline'"
            class="rounded-full"
            @click="togglePeriod(p.value)"
          >
            {{ p.label }}
          </UButton>
        </div>
      </UFormField>

      <UFormField label="Commentaire">
        <RichTextEditor v-model="form.comment" placeholder="Dosage, déroulé, conseils du médecin…" />
      </UFormField>

      <p class="text-sm text-muted flex items-center gap-1.5">
        <UIcon name="i-lucide-user-pen" class="size-4" />
        <template v-if="original">
          Ajoutée par <strong class="text-default">{{ authorName(original.created_by) }}</strong>
          le {{ formatDateTime(original.created_at) }}
        </template>
        <template v-else>
          Sera enregistrée à votre nom
        </template>
      </p>

      <UButton type="submit" block size="xl" icon="i-lucide-save" :loading="saving">
        Enregistrer
      </UButton>
    </form>

    <UModal v-model:open="confirmDelete" title="Supprimer cette démarche ?" description="Cette action est réversible quelques secondes.">
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
