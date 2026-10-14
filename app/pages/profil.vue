<script setup lang="ts">
interface OwnedJournal {
  journal_id: string
  journal_name: string
  other_members: number
}

const supabase = useSupabase()
const { user, deleteAccount } = useAuth()
const { online, sync, pendingCount } = useSync()
const toast = useToast()
const db = useDb()

const displayName = ref('')
const loading = ref(false)

onMounted(async () => {
  if (!online.value) return
  const { data } = await supabase.from('profiles').select('display_name').eq('id', user.value!.id).single()
  displayName.value = data?.display_name ?? ''
})

async function save() {
  loading.value = true
  try {
    const { error } = await supabase.from('profiles').update({ display_name: displayName.value.trim() }).eq('id', user.value!.id)
    if (error) throw error
    toast.add({ title: 'Profil enregistré', color: 'success' })
    sync()
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    loading.value = false
  }
}

// --- Suppression du compte ---
const deleteOpen = ref(false)
const preview = ref<OwnedJournal[] | null>(null)
const memberOf = ref<string[]>([])
const acknowledged = ref(false)
const deleting = ref(false)

const ownedShared = computed(() => (preview.value ?? []).filter(j => j.other_members > 0))
const ownedAlone = computed(() => (preview.value ?? []).filter(j => j.other_members === 0))
const canDelete = computed(() => !!preview.value && (!ownedShared.value.length || acknowledged.value))

async function openDelete() {
  preview.value = null
  acknowledged.value = false
  deleteOpen.value = true
  try {
    const { data, error } = await supabase.rpc('account_deletion_preview')
    if (error) throw error
    preview.value = data as OwnedJournal[]
    // journaux dont on est simple membre (données locales, à jour après synchro)
    const owned = new Set(preview.value.map(j => j.journal_id))
    memberOf.value = (await db.journals.toArray()).filter(j => !owned.has(j.id) && !j.deleted_at).map(j => j.name)
  } catch (e) {
    deleteOpen.value = false
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  }
}

async function confirmDelete() {
  deleting.value = true
  try {
    await deleteAccount()
    deleteOpen.value = false
    toast.add({ title: 'Compte supprimé', description: 'Toutes vos données ont été effacées.', icon: 'i-lucide-check' })
    await navigateTo('/connexion')
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    deleting.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <h1 class="text-2xl font-bold">
      Mon profil
    </h1>
    <UCard>
      <form class="space-y-4" @submit.prevent="save">
        <UFormField label="Email">
          <UInput :model-value="user?.email" disabled size="lg" class="w-full" />
        </UFormField>
        <UFormField label="Nom affiché" help="Visible par les autres membres de vos journaux">
          <UInput v-model="displayName" size="lg" class="w-full" required />
        </UFormField>
        <UButton type="submit" block size="lg" :loading="loading" :disabled="!online">
          {{ online ? 'Enregistrer' : 'Connexion requise' }}
        </UButton>
      </form>
    </UCard>

    <UCard :ui="{ root: 'ring-error/40' }">
      <template #header>
        <h2 class="font-semibold text-error">
          Supprimer mon compte
        </h2>
        <p class="text-sm text-muted">
          Suppression définitive de votre compte et de vos données. Cette action est irréversible.
        </p>
      </template>
      <UButton block color="error" variant="soft" icon="i-lucide-user-x" :disabled="!online" @click="openDelete">
        {{ online ? 'Supprimer mon compte…' : 'Connexion requise' }}
      </UButton>
    </UCard>

    <UModal v-model:open="deleteOpen" title="Supprimer votre compte ?" description="Cette action est définitive.">
      <template #body>
        <div v-if="!preview" class="flex justify-center py-6">
          <UIcon name="i-lucide-loader-circle" class="size-8 animate-spin text-muted" />
        </div>
        <div v-else class="space-y-4 text-sm">
          <UAlert
            v-if="ownedShared.length"
            icon="i-lucide-triangle-alert"
            color="error"
            variant="soft"
            title="Des journaux partagés seront supprimés pour tout le monde"
          >
            <template #description>
              <ul class="list-disc pl-4 mt-1 space-y-0.5">
                <li v-for="j in ownedShared" :key="j.journal_id">
                  <strong>{{ j.journal_name }}</strong> : {{ j.other_members }} autre(s) membre(s) perdront l'accès et tout l'historique
                </li>
              </ul>
            </template>
          </UAlert>

          <div v-if="ownedAlone.length">
            <p class="font-medium">
              Vos journaux supprimés avec leurs réveils :
            </p>
            <ul class="list-disc pl-5 text-muted">
              <li v-for="j in ownedAlone" :key="j.journal_id">
                {{ j.journal_name }}
              </li>
            </ul>
          </div>

          <div v-if="memberOf.length">
            <p class="font-medium">
              Journaux que vous quitterez :
            </p>
            <ul class="list-disc pl-5 text-muted">
              <li v-for="name in memberOf" :key="name">
                {{ name }}
              </li>
            </ul>
            <p class="text-xs text-muted mt-1">
              Ces journaux sont conservés. Les réveils que vous y avez saisis restent visibles, sans votre nom.
            </p>
          </div>

          <p v-if="!preview.length && !memberOf.length" class="text-muted">
            Vous n'avez aucun journal. Seul votre compte sera supprimé.
          </p>

          <UAlert
            v-if="pendingCount"
            icon="i-lucide-cloud-off"
            color="warning"
            variant="soft"
            :title="`${pendingCount} modification(s) non synchronisée(s) seront perdues`"
          />

          <UCheckbox
            v-if="ownedShared.length"
            v-model="acknowledged"
            label="Je comprends que ces journaux seront supprimés pour tous leurs membres"
          />
        </div>
      </template>
      <template #footer>
        <div class="flex gap-2 w-full">
          <UButton color="neutral" variant="ghost" class="flex-1 justify-center" @click="deleteOpen = false">
            Annuler
          </UButton>
          <UButton color="error" class="flex-1 justify-center" :loading="deleting" :disabled="!canDelete" @click="confirmDelete">
            Supprimer définitivement
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
